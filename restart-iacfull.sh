#!/bin/bash

# Script para reiniciar aplicações via Ansible (execução LOCAL)
# 
# Este script permite reiniciar apps sem usar CI/CD (GitHub Actions ou Bitbucket)
# Útil para: debug, hotfix urgente, ou restart rápido
#
# Pré-requisitos:
#   - Ansible instalado localmente
#   - Chave SSH configurada (~/.ssh/ansible_ssh_key)
#   - Variáveis de ambiente configuradas (ver abaixo)
#   - Acesso de rede ao servidor
#
# Uso: 
#   ./restart-iacfull.sh [nome-da-app]
#
# Exemplos:
#   ./restart-iacfull.sh                    # Menu interativo
#   ./restart-iacfull.sh landing-page       # Reinicia app específica

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Caminhos
APPS_FILE="iacfull/iac-full-nginx-proxies/apps.yaml"
ANSIBLE_DIR="iacfull/iac-full-nginx-proxies/ansible"
INVENTORY="$ANSIBLE_DIR/digitalocean.yaml"
PLAYBOOK="$ANSIBLE_DIR/playbooks/deploy_app.yaml"

# Verifica arquivos necessários
if [ ! -f "$APPS_FILE" ]; then
    echo -e "${RED}❌ Arquivo apps.yaml não encontrado em: $APPS_FILE${NC}"
    exit 1
fi

if [ ! -f "$PLAYBOOK" ]; then
    echo -e "${RED}❌ Playbook deploy_app.yaml não encontrado${NC}"
    exit 1
fi

# Verifica variáveis de ambiente necessárias
if [ -z "$DOCKER_USERNAME" ] || [ -z "$DOCKER_PASSWORD" ] || [ -z "$DOCKER_REPO" ]; then
    echo -e "${YELLOW}⚠️  Variáveis de ambiente não configuradas!${NC}"
    echo "Execute:"
    echo "  export DOCKER_USERNAME='seu-usuario'"
    echo "  export DOCKER_PASSWORD='seu-token'"
    echo "  export DOCKER_REPO='registry.digitalocean.com/seu-registry'"
    exit 1
fi

# Lê aplicações disponíveis do apps.yaml
AVAILABLE_APPS=($(grep -E '^\s+- name:' "$APPS_FILE" | sed 's/.*name: *//'))

if [ ${#AVAILABLE_APPS[@]} -eq 0 ]; then
    echo -e "${RED}❌ Nenhuma aplicação encontrada em apps.yaml${NC}"
    exit 1
fi

SELECTED_APP=""

# Se passou argumento, usa ele
if [ $# -gt 0 ]; then
    SELECTED_APP="$1"
    
    # Valida se existe
    if [[ ! " ${AVAILABLE_APPS[@]} " =~ " ${SELECTED_APP} " ]]; then
        echo -e "${RED}❌ Aplicação '$SELECTED_APP' não encontrada!${NC}"
        echo "Disponíveis: ${AVAILABLE_APPS[*]}"
        exit 1
    fi
else
    # Menu interativo
    echo -e "${BLUE}🧩 Aplicações disponíveis:${NC}"
    i=1
    for app in "${AVAILABLE_APPS[@]}"; do
        echo "  [$i] $app"
        ((i++))
    done
    
    echo ""
    read -p "👉 Digite o número da aplicação para reiniciar: " selection
    
    if [[ ! $selection =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "${#AVAILABLE_APPS[@]}" ]; then
        echo -e "${RED}❌ Seleção inválida!${NC}"
        exit 1
    fi
    
    SELECTED_APP="${AVAILABLE_APPS[$((selection-1))]}"
fi

echo ""
echo -e "${GREEN}🚀 Reiniciando aplicação: $SELECTED_APP${NC}"
echo ""

# Pergunta pela tag da imagem
read -p "📦 Tag da imagem (default: latest): " IMAGE_TAG
IMAGE_TAG=${IMAGE_TAG:-latest}

FULL_IMAGE_PATH="${DOCKER_REPO}/${SELECTED_APP}:${IMAGE_TAG}"

echo ""
echo "---------------------------------------------"
echo -e "${YELLOW}Configuração:${NC}"
echo "  App: $SELECTED_APP"
echo "  Imagem: $FULL_IMAGE_PATH"
echo "  Inventário: $INVENTORY"
echo "---------------------------------------------"
echo ""

read -p "Continuar? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Cancelado."
    exit 0
fi

echo ""
echo -e "${BLUE}⏳ Executando Ansible...${NC}"
echo ""

# Executa o playbook
ansible-playbook \
  "$PLAYBOOK" \
  -i "$INVENTORY" \
  --limit app-server \
  --user root \
  --private-key ~/.ssh/ansible_ssh_key \
  --extra-vars "@$APPS_FILE" \
  --extra-vars "app_to_deploy=$SELECTED_APP" \
  --extra-vars "full_image_path=$FULL_IMAGE_PATH" \
  --extra-vars "docker_username=$DOCKER_USERNAME" \
  --extra-vars "docker_password=$DOCKER_PASSWORD"

EXIT_CODE=$?

echo ""
echo "---------------------------------------------"
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Aplicação '$SELECTED_APP' reiniciada com sucesso!${NC}"
else
    echo -e "${RED}❌ Erro ao reiniciar '$SELECTED_APP' (código: $EXIT_CODE)${NC}"
fi
echo "---------------------------------------------"

exit $EXIT_CODE