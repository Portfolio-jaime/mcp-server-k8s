#!/bin/bash

# Script para iniciar el servidor MCP HTTP en el devcontainer

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_header "🔐 Iniciando MCP HTTPS Server en DevContainer"

# Verificar que estamos en el directorio correcto
if [ ! -f "package.json" ]; then
    print_warning "No se encontró package.json, cambiando a /workspace"
    cd /workspace
fi

# Verificar que el proyecto esté construido
if [ ! -d "dist" ] || [ ! -f "dist/https-server.js" ]; then
    print_status "Construyendo proyecto..."
    npm run build
fi

# Verificar conectividad con Kubernetes
print_status "Verificando conectividad con Kubernetes..."
if kubectl cluster-info &>/dev/null; then
    print_status "✅ Conectado al cluster Kubernetes"
    CLUSTER_NAME=$(kubectl config current-context 2>/dev/null || echo "unknown")
    print_status "📡 Contexto actual: $CLUSTER_NAME"
else
    print_warning "⚠️  No se puede conectar al cluster Kubernetes"
    print_warning "Asegúrate de que minikube esté corriendo o el cluster configurado"
fi

# Verificar helm
if command -v helm &>/dev/null; then
    print_status "✅ Helm disponible"
else
    print_warning "⚠️  Helm no encontrado"
fi

# Configurar puerto
export PORT=3002

print_status "🔐 Iniciando servidor HTTPS MCP..."
print_status "📡 Puerto: $PORT"
print_status "🔗 URL interna: https://localhost:$PORT/mcp"
print_status "🔗 URL externa: https://localhost:$PORT/mcp (desde host)"
print_status "💻 Para Claude Desktop usa: https://localhost:$PORT/mcp"

echo ""
print_status "🎯 El servidor estará disponible en:"
echo "   • Información: https://localhost:$PORT"
echo "   • Health check: https://localhost:$PORT/health"
echo "   • MCP Endpoint: https://localhost:$PORT/mcp"
echo ""

print_warning "⚠️  Tu navegador mostrará advertencia de certificado self-signed"
print_warning "   En Chrome: 'Advanced' → 'Proceed to localhost (unsafe)'"
echo ""

print_status "🛑 Para detener el servidor: Ctrl+C"
echo ""

# Iniciar el servidor HTTPS
npm run start:https