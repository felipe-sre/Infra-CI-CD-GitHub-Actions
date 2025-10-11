#!/bin/bash

# Script para reiniciar containers Docker (um, vários ou todos)
# Lê os serviços a partir do docker-compose.yml e permite seleção interativa.
# Uso: ./restart-cleaners.sh [servico1 servico2 ...]
# Se nenhum serviço for informado via argumento ou seleção, reinicia todos.

set -e

# Função para detectar o comando docker compose
compose_cmd() {
    if docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    elif docker-compose version >/dev/null 2>&1; then
        echo "docker-compose"
    else
        echo "❌ Nem 'docker compose' nem 'docker-compose' encontrados." >&2
        exit 1
    fi
}

DCMD=$(compose_cmd)

# Caminho do docker-compose.yml
COMPOSE_FILE="./docker-compose.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Arquivo docker-compose.yml não encontrado em $(pwd)"
    exit 1
fi

# Obtém lista de serviços definidos no compose
AVAILABLE_SERVICES=($($DCMD config --services))
SELECTED_SERVICES=()

# Se o usuário passou nomes diretamente como argumentos, usa eles
if [ $# -gt 0 ]; then
    SELECTED_SERVICES=("$@")
else
    echo "🧩 Serviços disponíveis:"
    i=1
    for svc in "${AVAILABLE_SERVICES[@]}"; do
        echo "  [$i] $svc"
        ((i++))
    done

    echo ""
    read -p "👉 Digite os números dos serviços que deseja reiniciar (ex: 1 3 4). Deixe em branco para todos: " -a selections

    if [ ${#selections[@]} -eq 0 ]; then
        SELECTED_SERVICES=("${AVAILABLE_SERVICES[@]}")
        echo "⚙️  Nenhum serviço selecionado. Todos serão reiniciados."
    else
        for num in "${selections[@]}"; do
            if [[ $num =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#AVAILABLE_SERVICES[@]}" ]; then
                SELECTED_SERVICES+=("${AVAILABLE_SERVICES[$((num-1))]}")
            else
                echo "⚠️  Ignorando entrada inválida: $num"
            fi
        done
    fi
fi

echo ""
echo "🚀 Serviços selecionados para reiniciar: ${SELECTED_SERVICES[*]}"
echo ""

for SERVICE in "${SELECTED_SERVICES[@]}"; do
    IMAGE=$(docker inspect --format='{{.Config.Image}}' "$SERVICE" 2>/dev/null || true)
    echo "---------------------------------------------"
    echo "⏹️  Parando serviço '$SERVICE'..."
    $DCMD stop "$SERVICE" || true

    echo "🗑️  Removendo container '$SERVICE'..."
    $DCMD rm -f "$SERVICE" || true

    if [ -n "$IMAGE" ]; then
        echo "🧹 Removendo imagem '$IMAGE'..."
        docker rmi "$IMAGE" || true
    fi

    echo "⬇️  Atualizando imagem e subindo '$SERVICE'..."
    $DCMD pull "$SERVICE" || true
    $DCMD up -d "$SERVICE"

    echo "✅ Serviço '$SERVICE' reiniciado com sucesso!"
done

echo "---------------------------------------------"
echo "🎉 Processo concluído!"

