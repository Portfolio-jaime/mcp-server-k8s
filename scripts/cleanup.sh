#!/bin/bash

# Script para limpiar el entorno de desarrollo

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[CLEANUP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "🧹 Iniciando limpieza del entorno..."

# Función para preguntar confirmación
confirm() {
    read -p "¿Estás seguro? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Mostrar estado actual
print_status "Estado actual del entorno:"
echo "Namespaces:"
kubectl get namespaces | grep -E "(testing|production|monitoring|cert-manager)" || echo "No hay namespaces de prueba"
echo ""
echo "Helm releases:"
helm list --all-namespaces || echo "No hay releases de Helm"
echo ""

# Opción 1: Limpieza completa
if [ "$1" = "--full" ] || [ "$1" = "-f" ]; then
    print_warning "Limpieza completa seleccionada. Esto eliminará:"
    echo "  - Todos los namespaces de prueba"
    echo "  - Todos los releases de Helm"
    echo "  - Minikube cluster"
    echo ""
    
    if confirm; then
        print_status "Eliminando releases de Helm..."
        helm uninstall nginx-test -n testing 2>/dev/null || true
        helm uninstall postgres-prod -n production 2>/dev/null || true
        helm uninstall redis-monitor -n monitoring 2>/dev/null || true
        helm uninstall prometheus -n monitoring 2>/dev/null || true
        helm uninstall cert-manager -n cert-manager 2>/dev/null || true
        
        print_status "Eliminando namespaces..."
        kubectl delete namespace testing --ignore-not-found=true
        kubectl delete namespace production --ignore-not-found=true
        kubectl delete namespace monitoring --ignore-not-found=true
        kubectl delete namespace cert-manager --ignore-not-found=true
        
        print_status "Deteniendo Minikube..."
        minikube stop
        
        print_status "Eliminando cluster de Minikube..."
        minikube delete
        
        print_status "✅ Limpieza completa terminada"
    else
        print_status "Limpieza cancelada"
        exit 0
    fi

# Opción 2: Limpieza suave (solo aplicaciones de prueba)
elif [ "$1" = "--soft" ] || [ "$1" = "-s" ]; then
    print_warning "Limpieza suave seleccionada. Esto eliminará solo las aplicaciones de prueba"
    echo ""
    
    if confirm; then
        print_status "Eliminando releases de Helm..."
        helm uninstall nginx-test -n testing 2>/dev/null || true
        helm uninstall postgres-prod -n production 2>/dev/null || true
        helm uninstall redis-monitor -n monitoring 2>/dev/null || true
        helm uninstall prometheus -n monitoring 2>/dev/null || true
        helm uninstall cert-manager -n cert-manager 2>/dev/null || true
        
        print_status "Eliminando pods standalone..."
        kubectl delete pod nginx-old -n testing --ignore-not-found=true
        kubectl delete pod nginx-new -n testing --ignore-not-found=true
        kubectl delete pod multi-container -n production --ignore-not-found=true
        
        print_status "Eliminando ConfigMaps y Secrets..."
        kubectl delete configmap app-config -n testing --ignore-not-found=true
        kubectl delete secret app-secrets -n production --ignore-not-found=true
        
        print_status "✅ Limpieza suave terminada"
    else
        print_status "Limpieza cancelada"
        exit 0
    fi

# Opción 3: Limpieza de builds
elif [ "$1" = "--build" ] || [ "$1" = "-b" ]; then
    print_status "Limpiando archivos de build..."
    rm -rf dist/
    rm -rf node_modules/
    npm cache clean --force
    print_status "✅ Archivos de build eliminados"

# Opción 4: Reiniciar Minikube
elif [ "$1" = "--restart" ] || [ "$1" = "-r" ]; then
    print_status "Reiniciando Minikube..."
    minikube stop
    minikube start --driver=docker --memory=4096 --cpus=2
    kubectl config use-context minikube
    print_status "✅ Minikube reiniciado"

# Mostrar ayuda
else
    echo "🧹 Script de limpieza del entorno K8s MCP"
    echo ""
    echo "Uso: $0 [OPCIÓN]"
    echo ""
    echo "Opciones:"
    echo "  -f, --full      Limpieza completa (elimina todo incluyendo Minikube)"
    echo "  -s, --soft      Limpieza suave (solo aplicaciones de prueba)"
    echo "  -b, --build     Limpiar archivos de build (dist/, node_modules/)"
    echo "  -r, --restart   Reiniciar Minikube"
    echo "  -h, --help      Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 --soft       # Eliminar solo aplicaciones de prueba"
    echo "  $0 --full       # Limpieza completa"
    echo "  $0 --build      # Limpiar solo archivos de build"
    echo ""
    
    # Mostrar estado si no se proporciona opción
    print_status "Estado actual:"
    echo "Pods activos: $(kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l)"
    echo "Helm releases: $(helm list --all-namespaces --short 2>/dev/null | wc -l)"
    echo "Minikube status: $(minikube status --format='{{.Host}}' 2>/dev/null || echo 'Detenido')"
fi

print_status "Comandos útiles post-limpieza:"
echo "  ./scripts/setup-k8s.sh    # Reconfigurar entorno de pruebas"
echo "  npm install && npm run build  # Reinstalar dependencias y construir"
echo "  minikube start            # Iniciar Minikube si fue detenido"