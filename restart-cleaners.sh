#!/bin/bash

# Script para reiniciar containers Docker
# Remove containers, imagens e reinicia os serviços

echo "Parando e removendo containers..."
docker-compose down

echo "Removendo imagem cleaners-api..."
docker rmi d34tecnologia/cleaners-api

echo "Removendo imagem cleaners-dashboard..."
docker rmi d34tecnologia/cleaners-dashboard

echo "Iniciando containers em modo detached..."
docker compose up -d

echo "Processo concluído!"
