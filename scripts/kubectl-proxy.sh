#!/bin/bash

# Proxy script para ejecutar kubectl dentro del devcontainer desde el host
# Permite que Claude Desktop (host) use kubectl del devcontainer

CONTAINER_NAME="argocd-mcp-development"

# Verificar si el container está corriendo
if ! docker ps --format "table {{.Names}}" | grep -q "$CONTAINER_NAME"; then
    echo "Error: Container $CONTAINER_NAME no está corriendo" >&2
    echo "Inicia el devcontainer en VS Code primero" >&2
    exit 1
fi

# Ejecutar kubectl dentro del container
docker exec -e KUBECONFIG=/home/node/.kube/config "$CONTAINER_NAME" kubectl "$@"