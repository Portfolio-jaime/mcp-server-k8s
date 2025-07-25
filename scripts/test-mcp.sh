#!/bin/bash

# Script para probar el servidor MCP de Kubernetes

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[TEST]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Función para probar comandos MCP usando stdio
test_mcp_command() {
    local test_name="$1"
    local tool_name="$2"
    local args="$3"
    
    print_status "Probando: $test_name"
    
    # Crear mensaje JSON para MCP
    local request=$(cat <<EOF
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "$tool_name",
    "arguments": $args
  }
}
EOF
)
    
    echo "$request" | node dist/index.js | jq '.' || {
        print_error "Falló: $test_name"
        return 1
    }
    
    echo ""
}

# Verificar que el proyecto esté construido
if [ ! -d "dist" ]; then
    print_status "Construyendo proyecto..."
    npm run build
fi

print_status "🧪 Iniciando pruebas del MCP Server..."

# Test 1: Listar herramientas disponibles
print_status "Listando herramientas disponibles..."
echo '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}' | node dist/index.js | jq '.result.tools[].name'

echo ""

# Test 2: Obtener información del cluster
test_mcp_command "Información del cluster" "get_cluster_info" "{}"

# Test 3: Obtener pods de todos los namespaces
test_mcp_command "Pods de todos los namespaces" "get_pods" "{}"

# Test 4: Obtener pods de un namespace específico
test_mcp_command "Pods del namespace testing" "get_pods" '{"namespace": "testing"}'

# Test 5: Obtener releases de Helm
test_mcp_command "Releases de Helm" "get_helm_releases" "{}"

# Test 6: Releases de Helm por namespace
test_mcp_command "Releases de Helm en monitoring" "get_helm_releases" '{"namespace": "monitoring"}'

# Test 7: Analizar versiones
test_mcp_command "Análisis de versiones" "analyze_versions" "{}"

# Test 8: Analizar versiones por namespace
test_mcp_command "Análisis de versiones en testing" "analyze_versions" '{"namespace": "testing"}'

# Test 9: Componentes desactualizados
test_mcp_command "Componentes desactualizados" "get_outdated_components" "{}"

# Test 10: Comparar versiones
test_mcp_command "Comparar versiones nginx" "compare_versions" '{
  "component": "nginx",
  "currentVersion": "1.20.2",
  "targetVersion": "1.25.3"
}'

print_status "✅ Todas las pruebas completadas!"

# Mostrar estadísticas del cluster para verificar
print_status "📊 Estadísticas del cluster actual:"
echo "Namespaces: $(kubectl get namespaces --no-headers | wc -l)"
echo "Pods total: $(kubectl get pods --all-namespaces --no-headers | wc -l)"
echo "Helm releases: $(helm list --all-namespaces --short | wc -l)"
echo "Servicios: $(kubectl get services --all-namespaces --no-headers | wc -l)"