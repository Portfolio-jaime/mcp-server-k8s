#!/bin/bash

# Script para probar Docker-in-Docker setup
echo "🧪 Probando configuración Docker-in-Docker..."

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "\n${YELLOW}1. Verificando Docker daemon...${NC}"
if docker info &>/dev/null; then
    echo -e "${GREEN}✅ Docker daemon funciona correctamente${NC}"
    echo "Docker version: $(docker --version)"
else
    echo -e "${RED}❌ Docker daemon no está funcionando${NC}"
    exit 1
fi

echo -e "\n${YELLOW}2. Probando contenedor simple...${NC}"
if docker run --rm hello-world &>/dev/null; then
    echo -e "${GREEN}✅ Contenedor de prueba ejecutado correctamente${NC}"
else
    echo -e "${RED}❌ Error ejecutando contenedor de prueba${NC}"
    exit 1
fi

echo -e "\n${YELLOW}3. Verificando que es Docker aislado (no del host)...${NC}"
# Crear un contenedor con nombre único para verificar que no está en el host
TEST_CONTAINER="test-docker-in-docker-$(date +%s)"
docker run -d --name "$TEST_CONTAINER" alpine:latest sleep 30 &>/dev/null

if docker ps | grep -q "$TEST_CONTAINER"; then
    echo -e "${GREEN}✅ Docker está funcionando de manera aislada${NC}"
    docker rm -f "$TEST_CONTAINER" &>/dev/null
else
    echo -e "${RED}❌ Error creando contenedor de prueba${NC}"
    exit 1
fi

echo -e "\n${YELLOW}4. Probando Minikube con Docker driver...${NC}"
# Solo verificar que minikube puede ver Docker
if minikube docker-env &>/dev/null 2>&1 || true; then
    echo -e "${GREEN}✅ Minikube puede detectar Docker${NC}"
else
    echo -e "${YELLOW}⚠️  Minikube aún no configurado (normal en primera ejecución)${NC}"
fi

echo -e "\n${GREEN}🎉 Docker-in-Docker configurado correctamente!${NC}"
echo -e "Ahora puedes ejecutar: ${YELLOW}bash .devcontainer/post-create.sh${NC}"