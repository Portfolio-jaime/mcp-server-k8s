#!/bin/bash

# Script para configurar MCP Server con Claude Desktop

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Obtener directorio del proyecto
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_CONFIG_DIR="$HOME/.config/claude-desktop"
CLAUDE_CONFIG_FILE="$CLAUDE_CONFIG_DIR/config.json"

print_status "🔧 Configurando MCP Server para Claude Desktop"

# 1. Verificar que el proyecto esté construido
if [ ! -f "$PROJECT_DIR/dist/index.js" ]; then
    print_status "Construyendo proyecto..."
    cd "$PROJECT_DIR"
    npm run build
fi

# 2. Crear directorio de configuración de Claude Desktop
print_status "Creando directorio de configuración..."
mkdir -p "$CLAUDE_CONFIG_DIR"

# 3. Verificar configuración de Kubernetes
if [ ! -f "$HOME/.kube/config" ]; then
    print_warning "No se encontró ~/.kube/config"
    print_warning "Asegúrate de tener configurado kubectl en tu sistema host"
fi

# 4. Crear configuración de Claude Desktop
print_status "Creando configuración de Claude Desktop..."

cat > "$CLAUDE_CONFIG_FILE" << EOF
{
  "mcpServers": {
    "k8s-versions": {
      "command": "node",
      "args": ["$PROJECT_DIR/dist/index.js"],
      "cwd": "$PROJECT_DIR",
      "env": {
        "KUBECONFIG": "$HOME/.kube/config",
        "NODE_ENV": "production"
      }
    }
  }
}
EOF

print_status "✅ Configuración creada en: $CLAUDE_CONFIG_FILE"

# 5. Verificar que Node.js esté disponible en el sistema host
if ! command -v node &> /dev/null; then
    print_error "Node.js no está instalado en el sistema host"
    print_error "Instala Node.js desde: https://nodejs.org/"
    exit 1
fi

# 6. Verificar dependencias
print_status "Verificando dependencias..."
cd "$PROJECT_DIR"

if [ ! -d "node_modules" ]; then
    print_status "Instalando dependencias de producción..."
    npm ci --production
fi

# 7. Probar configuración
print_status "Probando configuración..."
if echo '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}' | node dist/index.js > /dev/null 2>&1; then
    print_status "✅ MCP Server funciona correctamente"
else
    print_error "❌ Error en MCP Server"
    exit 1
fi

# 8. Mostrar siguiente pasos
echo ""
print_status "🎉 Configuración completada!"
echo ""
echo -e "${YELLOW}📋 Siguientes pasos:${NC}"
echo "1. Reinicia Claude Desktop si está abierto"
echo "2. Abre Claude Desktop"
echo "3. Deberías ver 'k8s-versions' disponible como herramienta"
echo "4. Prueba preguntando: '¿Qué pods tengo en mi cluster?'"
echo ""
echo -e "${YELLOW}📁 Archivos importantes:${NC}"
echo "• Configuración: $CLAUDE_CONFIG_FILE"
echo "• MCP Server: $PROJECT_DIR/dist/index.js"
echo "• Logs: Revisa la consola de Claude Desktop para debug"
echo ""
echo -e "${YELLOW}🔧 Troubleshooting:${NC}"
echo "• Si no funciona, revisa que kubectl funcione en tu sistema host"
echo "• Verifica que tengas acceso al cluster desde fuera del devcontainer"
echo "• Revisa los logs de Claude Desktop para errores"