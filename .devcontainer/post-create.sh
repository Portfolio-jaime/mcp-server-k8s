#!/bin/bash

# Script de configuración post-creación del devcontainer mejorado
# Este script se ejecuta después de crear el container

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función para imprimir con colores
print_header() {
    echo -e "\n${PURPLE}=== $1 ===${NC}\n"
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# Función para verificar comandos
check_command() {
    if command -v $1 &> /dev/null; then
        print_status "$1 está disponible ✅"
        return 0
    else
        print_error "$1 no está disponible ❌"
        return 1
    fi
}

# Función para esperar con timeout
wait_for_condition() {
    local condition="$1"
    local timeout="${2:-300}"
    local interval="${3:-5}"
    local count=0
    
    while ! eval "$condition" && [ $count -lt $timeout ]; do
        sleep $interval
        count=$((count + interval))
        echo -n "."
    done
    
    if [ $count -ge $timeout ]; then
        return 1
    fi
    return 0
}

print_header "🚀 Configurando entorno de desarrollo K8s MCP"

# Verificar que estamos en el directorio correcto
if [ ! -f "package.json" ]; then
    print_warning "No se encontró package.json, cambiando a /workspace"
    cd /workspace
fi

# 1. Verificar herramientas instaladas
print_step "1. Verificando herramientas instaladas"
check_command "node" || exit 1
check_command "npm" || exit 1
check_command "kubectl" || exit 1
check_command "helm" || exit 1
check_command "minikube" || exit 1
check_command "docker" || exit 1

# Mostrar versiones
print_status "Versiones instaladas:"
echo "  Node.js: $(node --version)"
echo "  NPM: $(npm --version)"
echo "  kubectl: $(kubectl version --client --short 2>/dev/null || echo 'Error')"
echo "  Helm: $(helm version --short 2>/dev/null || echo 'Error')"
echo "  Minikube: $(minikube version --short 2>/dev/null || echo 'Error')"
echo "  Docker: $(docker --version 2>/dev/null || echo 'Error')"

# 2. Configurar permisos y directorios
print_step "2. Configurando permisos y directorios"

# Crear directorios necesarios
mkdir -p ~/.kube
mkdir -p ~/.minikube
mkdir -p ~/.config/helm
mkdir -p ~/.cache/helm
mkdir -p ~/.local/share/helm
mkdir -p ~/.npm

# Verificar Docker-in-Docker
print_status "Verificando Docker-in-Docker..."
if systemctl is-active --quiet docker 2>/dev/null; then
    print_status "Docker daemon está corriendo ✅"
elif pgrep dockerd > /dev/null 2>&1; then
    print_status "Docker daemon detectado ✅"
else
    print_status "Iniciando Docker daemon..."
    sudo service docker start 2>/dev/null || print_warning "Error iniciando Docker daemon"
fi

# Verificar acceso a Docker
if docker ps &>/dev/null; then
    print_status "Docker funciona correctamente ✅"
else
    print_warning "Problemas con acceso a Docker - puede necesitar reiniciar el container"
fi

# 3. Instalar dependencias de Node.js
print_step "3. Instalando dependencias de Node.js"
if [ -f "package.json" ]; then
    print_status "Configurando permisos para node_modules..."
    sudo chown -R node:node /workspace/node_modules 2>/dev/null || true
    sudo chmod -R 755 /workspace 2>/dev/null || true
    
    print_status "Instalando dependencias del proyecto..."
    npm ci --prefer-offline --no-audit 2>/dev/null || npm install
    print_status "Dependencias instaladas ✅"
else
    print_warning "No se encontró package.json, omitiendo instalación de dependencias"
fi

# 4. Configurar Git (omitido - usa la configuración del host)
print_step "4. Configurando Git"
print_status "Usando configuración de Git del host (montada automáticamente) ✅"

# 5. Inicializar Minikube
print_step "5. Inicializando Minikube"

# Verificar si Minikube ya está corriendo
if minikube status &>/dev/null; then
    print_status "Minikube ya está corriendo ✅"
    MINIKUBE_RUNNING=true
else
    print_status "Iniciando Minikube (esto puede tomar varios minutos)..."
    
    # Configurar driver de Minikube
    export MINIKUBE_DRIVER=docker
    export MINIKUBE_HOME=~/.minikube
    
    # Iniciar Minikube con configuración optimizada
    if minikube start \
        --driver=docker \
        --memory=4096 \
        --cpus=2 \
        --disk-size=20g \
        --kubernetes-version=v1.28.3 \
        --container-runtime=docker \
        --extra-config=kubelet.housekeeping-interval=10s; then
        
        print_status "Minikube iniciado correctamente ✅"
        MINIKUBE_RUNNING=true
    else
        print_error "Error iniciando Minikube ❌"
        MINIKUBE_RUNNING=false
    fi
fi

# 6. Configurar kubectl
print_step "6. Configurando kubectl"
if [ "$MINIKUBE_RUNNING" = true ]; then
    # Configurar contexto de kubectl
    kubectl config use-context minikube
    
    # Verificar conectividad
    if kubectl cluster-info &>/dev/null; then
        print_status "kubectl configurado correctamente ✅"
        
        # Mostrar información del cluster
        echo "Información del cluster:"
        kubectl get nodes
        echo ""
        kubectl get namespaces
    else
        print_warning "Problemas con conectividad de kubectl"
    fi
else
    print_warning "Minikube no está corriendo, omitiendo configuración de kubectl"
fi

# 7. Configurar Helm
print_step "7. Configurando Helm"

# Agregar repositorios comunes de Helm
print_status "Agregando repositorios de Helm..."

repos=(
    "stable|https://charts.helm.sh/stable"
    "bitnami|https://charts.bitnami.com/bitnami"
    "prometheus-community|https://prometheus-community.github.io/helm-charts"
    "grafana|https://grafana.github.io/helm-charts"
    "ingress-nginx|https://kubernetes.github.io/ingress-nginx"
    "jetstack|https://charts.jetstack.io"
    "elastic|https://helm.elastic.co"
    "argo|https://argoproj.github.io/argo-helm"
)

for repo in "${repos[@]}"; do
    IFS='|' read -r name url <<< "$repo"
    if helm repo add "$name" "$url" 2>/dev/null; then
        print_status "✅ Repositorio $name agregado"
    else
        print_warning "⚠️  Error agregando repositorio $name"
    fi
done

# Actualizar repositorios
print_status "Actualizando repositorios de Helm..."
if helm repo update; then
    print_status "Repositorios actualizados ✅"
else
    print_warning "Error actualizando repositorios"
fi

# 8. Construir el proyecto MCP
print_step "8. Construyendo proyecto MCP"
if [ -f "package.json" ] && [ -f "tsconfig.json" ]; then
    print_status "Compilando TypeScript..."
    if npm run build; then
        print_status "Proyecto compilado correctamente ✅"
    else
        print_warning "Error compilando el proyecto"
    fi
else
    print_warning "Archivos de configuración no encontrados, omitiendo build"
fi

# 9. Configurar scripts ejecutables
print_step "9. Configurando scripts"
if [ -d "scripts" ]; then
    chmod +x scripts/*.sh 2>/dev/null || true
    print_status "Scripts configurados como ejecutables ✅"
fi

# 10. Configurar aliases y funciones útiles
print_step "10. Configurando aliases y funciones"

# Agregar aliases al .bashrc si no existen
ALIASES="
# Aliases para Kubernetes y MCP
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgn='kubectl get nodes'
alias kgns='kubectl get namespaces'
alias kdp='kubectl describe pod'
alias kds='kubectl describe service'
alias klogs='kubectl logs'
alias kexec='kubectl exec -it'

# Aliases para Helm
alias h='helm'
alias hls='helm list --all-namespaces'
alias hst='helm status'
alias hget='helm get'

# Aliases para el proyecto MCP
alias mcp-start='npm run start'
alias mcp-dev='npm run dev'
alias mcp-build='npm run build'
alias mcp-test='./scripts/test-mcp.sh'
alias mcp-setup='./scripts/setup-k8s.sh'
alias mcp-clean='./scripts/cleanup.sh'

# Funciones útiles
function kns() {
    kubectl config set-context --current --namespace=\$1
}

function pod-logs() {
    kubectl logs -f \$(kubectl get pods --no-headers -o custom-columns=\":metadata.name\" | grep \$1 | head -1)
}

function helm-install-example() {
    echo 'Ejemplos de instalación con Helm:'
    echo '  helm install nginx bitnami/nginx --namespace testing --create-namespace'
    echo '  helm install postgres bitnami/postgresql --namespace production --create-namespace'
}
"

# Verificar si los aliases ya están en .bashrc
if ! grep -q "# Aliases para Kubernetes y MCP" ~/.bashrc 2>/dev/null; then
    echo "$ALIASES" >> ~/.bashrc
    print_status "Aliases agregados a .bashrc ✅"
fi

# 11. Configuración de VS Code workspace
print_step "11. Configurando workspace de VS Code"

# Crear configuración de workspace si no existe
if [ ! -f ".vscode/settings.json" ]; then
    mkdir -p .vscode
    cat > .vscode/settings.json << 'EOF'
{
  "kubernetes.defaultNamespace": "default",
  "files.associations": {
    "*.yaml": "yaml",
    "*.yml": "yaml"
  },
  "yaml.schemas": {
    "kubernetes": [
      "*.yaml",
      "*.yml",
      "k8s/**/*.yaml",
      "deployments/**/*.yaml"
    ]
  }
}
EOF
    print_status "Configuración de VS Code creada ✅"
fi

# 12. Verificación final del entorno
print_step "12. Verificación final del entorno"

print_status "Verificando componentes del sistema..."

# Verificar Minikube
if minikube status &>/dev/null; then
    print_status "✅ Minikube: CORRIENDO"
    MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "No disponible")
    echo "    IP: $MINIKUBE_IP"
else
    print_warning "⚠️  Minikube: DETENIDO"
fi

# Verificar kubectl
if kubectl cluster-info &>/dev/null; then
    print_status "✅ kubectl: CONECTADO"
    CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "ninguno")
    echo "    Contexto: $CURRENT_CONTEXT"
else
    print_warning "⚠️  kubectl: DESCONECTADO"
fi

# Verificar Helm
HELM_REPOS=$(helm repo list 2>/dev/null | wc -l)
if [ "$HELM_REPOS" -gt 1 ]; then
    print_status "✅ Helm: CONFIGURADO ($((HELM_REPOS-1)) repositorios)"
else
    print_warning "⚠️  Helm: SIN REPOSITORIOS"
fi

# Verificar proyecto MCP
if [ -f "dist/index.js" ]; then
    print_status "✅ Proyecto MCP: COMPILADO"
else
    print_warning "⚠️  Proyecto MCP: NO COMPILADO"
fi

# 13. Resumen y próximos pasos
print_header "🎉 Configuración completada"

echo -e "${GREEN}Entorno de desarrollo K8s MCP configurado exitosamente!${NC}"
echo ""
echo -e "${CYAN}📋 Resumen del entorno:${NC}"
echo "  • Node.js $(node --version)"
echo "  • Kubernetes $(kubectl version --client --short 2>/dev/null | cut -d' ' -f3 || echo 'Error')"
echo "  • Helm $(helm version --short 2>/dev/null | cut -d' ' -f2 || echo 'Error')"
echo "  • Minikube $(minikube version --short 2>/dev/null | cut -d' ' -f3 || echo 'Error')"
echo ""

echo -e "${YELLOW}🚀 Comandos principales:${NC}"
echo "  mcp-setup          # Configurar aplicaciones de ejemplo en K8s"
echo "  mcp-build          # Compilar el proyecto MCP"
echo "  mcp-dev            # Iniciar MCP en modo desarrollo"
echo "  mcp-test           # Ejecutar pruebas del MCP"
echo ""

echo -e "${YELLOW}🔧 Comandos de Kubernetes:${NC}"
echo "  k get pods --all-namespaces    # Ver todos los pods"
echo "  hls                            # Ver releases de Helm"
echo "  minikube dashboard             # Abrir dashboard web"
echo "  minikube service list          # Ver servicios expuestos"
echo ""

echo -e "${YELLOW}📚 Próximos pasos recomendados:${NC}"
echo "  1. Ejecutar: mcp-setup         # Instalar aplicaciones de ejemplo"
echo "  2. Ejecutar: mcp-build         # Compilar el proyecto"
echo "  3. Ejecutar: mcp-test          # Probar funcionalidades"
echo "  4. Ejecutar: mcp-dev           # Iniciar desarrollo"
echo ""

if [ "$MINIKUBE_RUNNING" = true ]; then
    echo -e "${GREEN}✅ Todo listo para empezar a desarrollar!${NC}"
else
    echo -e "${YELLOW}⚠️  Nota: Ejecuta 'minikube start' para iniciar el cluster${NC}"
fi

# Crear archivo de estado para verificación
cat > .devcontainer-setup-complete << EOF
DevContainer setup completed successfully!
Date: $(date)
Minikube Status: $(minikube status --format='{{.Host}}' 2>/dev/null || echo 'Stopped')
kubectl Context: $(kubectl config current-context 2>/dev/null || echo 'None')
Helm Repos: $(helm repo list 2>/dev/null | wc -l)
EOF

print_status "Archivo de estado creado: .devcontainer-setup-complete"
echo ""