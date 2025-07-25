#!/bin/bash

# Script para probar el servidor MCP HTTPS

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[TEST]${NC} $1"
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

# Configuración
BASE_URL="https://localhost:3002"
MCP_URL="$BASE_URL/mcp"

print_header "🧪 Probando MCP HTTPS Server"

# Test 1: Health Check
print_status "1. Probando health check..."
if curl -k -s "$BASE_URL/health" | jq -e '.status == "healthy"' > /dev/null 2>&1; then
    print_status "✅ Health check OK"
else
    print_error "❌ Health check FAILED"
    exit 1
fi

# Test 2: Página de información
print_status "2. Probando página de información..."
if curl -k -s "$BASE_URL" | grep -q "Kubernetes MCP HTTPS Server"; then
    print_status "✅ Página de información OK"
else
    print_error "❌ Página de información FAILED"
    exit 1
fi

# Test 3: Listar herramientas MCP
print_status "3. Probando listado de herramientas MCP..."
TOOLS_RESPONSE=$(curl -k -s -X POST "$MCP_URL" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}')

if echo "$TOOLS_RESPONSE" | jq -e '.result.tools | length > 0' > /dev/null 2>&1; then
    TOOL_COUNT=$(echo "$TOOLS_RESPONSE" | jq -r '.result.tools | length')
    print_status "✅ Encontradas $TOOL_COUNT herramientas MCP"
    
    # Mostrar herramientas disponibles
    echo "   Herramientas disponibles:"
    echo "$TOOLS_RESPONSE" | jq -r '.result.tools[].name' | sed 's/^/   • /'
else
    print_error "❌ Error listando herramientas MCP"
    echo "$TOOLS_RESPONSE" | jq .
    exit 1
fi

# Test 4: Probar herramienta específica (get_namespaces)
print_status "4. Probando herramienta get_namespaces..."
NS_RESPONSE=$(curl -k -s -X POST "$MCP_URL" \
    -H "Content-Type: application/json" \
    -d '{
        "jsonrpc": "2.0", 
        "id": 1, 
        "method": "tools/call",
        "params": {
            "name": "get_namespaces",
            "arguments": {}
        }
    }')

if echo "$NS_RESPONSE" | jq -e '.result.content[0].text' > /dev/null 2>&1; then
    print_status "✅ Herramienta get_namespaces OK"
    # Mostrar resultado (primeras líneas)
    echo "   Resultado:"
    echo "$NS_RESPONSE" | jq -r '.result.content[0].text' | head -3 | sed 's/^/   /'
else
    print_error "❌ Error ejecutando get_namespaces"
    echo "$NS_RESPONSE" | jq .
fi

# Test 5: Probar herramienta con argumentos (get_pods)
print_status "5. Probando herramienta get_pods con namespace..."
PODS_RESPONSE=$(curl -k -s -X POST "$MCP_URL" \
    -H "Content-Type: application/json" \
    -d '{
        "jsonrpc": "2.0", 
        "id": 1, 
        "method": "tools/call",
        "params": {
            "name": "get_pods",
            "arguments": {"namespace": "kube-system"}
        }
    }')

if echo "$PODS_RESPONSE" | jq -e '.result.content[0].text' > /dev/null 2>&1; then
    print_status "✅ Herramienta get_pods OK"
    # Mostrar resultado (primeras líneas)
    echo "   Resultado:"
    echo "$PODS_RESPONSE" | jq -r '.result.content[0].text' | head -3 | sed 's/^/   /'
else
    print_warning "⚠️  get_pods puede fallar si no hay conectividad con K8s"
    echo "$PODS_RESPONSE" | jq .
fi

# Test 6: Verificar certificados
print_status "6. Verificando certificados SSL..."
if [ -f "certs/server.key" ] && [ -f "certs/server.crt" ]; then
    print_status "✅ Certificados encontrados"
    
    # Mostrar información del certificado
    CERT_INFO=$(openssl x509 -in certs/server.crt -text -noout 2>/dev/null || echo "Error leyendo certificado")
    if echo "$CERT_INFO" | grep -q "CN = localhost"; then
        print_status "✅ Certificado para localhost OK"
    else
        print_warning "⚠️  Certificado puede no ser para localhost"
    fi
else
    print_warning "⚠️  Certificados no encontrados (se generarán automáticamente)"
fi

# Resumen final
print_header "📊 Resumen de Pruebas"

echo ""
print_status "🎯 URLs para Claude Desktop:"
echo "   • MCP Endpoint: $MCP_URL"
echo "   • Información:  $BASE_URL"
echo "   • Health:       $BASE_URL/health"

echo ""
print_status "🛠️ Herramientas verificadas:"
if [ -n "$TOOLS_RESPONSE" ]; then
    echo "$TOOLS_RESPONSE" | jq -r '.result.tools[].name' | sed 's/^/   • /'
fi

echo ""
print_status "✅ Servidor MCP HTTPS funcionando correctamente"
print_status "📱 Puedes configurar Claude Desktop con: $MCP_URL"

echo ""
print_warning "⚠️  Recuerda aceptar el certificado self-signed en Claude Desktop"