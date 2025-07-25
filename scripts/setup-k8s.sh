#!/bin/bash

# Script para configurar el entorno Kubernetes con aplicaciones de ejemplo
# para probar el MCP server

set -e

echo "🚀 Configurando entorno Kubernetes para pruebas del MCP..."

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir con colores
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar que minikube esté corriendo
if ! minikube status &>/dev/null; then
    print_status "Iniciando Minikube..."
    minikube start --driver=docker --memory=4096 --cpus=2
else
    print_status "Minikube ya está corriendo"
fi

# Configurar kubectl context
print_status "Configurando contexto de kubectl..."
kubectl config use-context minikube

# Crear namespaces
print_status "Creando namespaces..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace testing --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Agregar repositorios de Helm
print_status "Configurando repositorios de Helm..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Instalar aplicaciones de ejemplo en diferentes versiones
print_status "Instalando aplicaciones de ejemplo..."

# Nginx en testing (versión específica)
print_status "Instalando Nginx en namespace 'testing'..."
helm upgrade --install nginx-test bitnami/nginx \
    --namespace testing \
    --version 15.4.4 \
    --set service.type=NodePort \
    --set service.nodePorts.http=30080 \
    --set image.tag=1.24.0 || true

# PostgreSQL en production (versión más nueva)
print_status "Instalando PostgreSQL en namespace 'production'..."
helm upgrade --install postgres-prod bitnami/postgresql \
    --namespace production \
    --version 12.12.10 \
    --set auth.postgresPassword=secretpassword \
    --set primary.persistence.enabled=false || true

# Redis en monitoring (versión anterior para simular desactualización)
print_status "Instalando Redis en namespace 'monitoring'..."
helm upgrade --install redis-monitor bitnami/redis \
    --namespace monitoring \
    --version 17.15.6 \
    --set auth.enabled=false \
    --set master.persistence.enabled=false \
    --set replica.persistence.enabled=false || true

# Prometheus stack (versión específica para testing)
print_status "Instalando Prometheus Stack..."
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --version 51.2.0 \
    --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=2Gi \
    --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage=1Gi \
    --set grafana.persistence.enabled=false \
    --set prometheus.prometheusSpec.retention=1d || true

# Instalar cert-manager (para testing de CRDs)
print_status "Instalando cert-manager..."
helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --version v1.13.2 \
    --set installCRDs=true || true

# Instalar ArgoCD (componente principal para el MCP server)
print_status "Instalando ArgoCD..."
helm upgrade --install argocd argo/argo-cd \
    --namespace argocd \
    --version 5.46.8 \
    --set server.service.type=NodePort \
    --set server.service.nodePortHttp=30080 \
    --set server.service.nodePortHttps=30443 \
    --set configs.params."server\.insecure"=true \
    --set server.extraArgs[0]="--insecure" || true

# Esperar a que ArgoCD esté listo
print_status "Esperando a que ArgoCD esté listo..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd || true

# Crear algunos pods standalone con diferentes versiones
print_status "Creando pods standalone..."

# Pod con nginx versión anterior
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nginx-old
  namespace: testing
  labels:
    app: nginx-standalone
    version: "1.20.2"
spec:
  containers:
  - name: nginx
    image: nginx:1.20.2
    ports:
    - containerPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: nginx-new
  namespace: testing
  labels:
    app: nginx-standalone
    version: "1.25.3"
spec:
  containers:
  - name: nginx
    image: nginx:1.25.3
    ports:
    - containerPort: 80
EOF

# Pod con múltiples contenedores
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: multi-container
  namespace: production
  labels:
    app: multi-app
    version: "mixed"
spec:
  containers:
  - name: web
    image: nginx:1.24.0
    ports:
    - containerPort: 80
  - name: sidecar
    image: busybox:1.35.0
    command: ["sleep", "3600"]
  - name: logger
    image: alpine:3.18.0
    command: ["tail", "-f", "/dev/null"]
EOF

# Crear ConfigMaps y Secrets para testing
print_status "Creando ConfigMaps y Secrets..."

kubectl create configmap app-config \
    --namespace=testing \
    --from-literal=database_url=postgres://localhost:5432/testdb \
    --from-literal=redis_url=redis://localhost:6379 \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic app-secrets \
    --namespace=production \
    --from-literal=api_key=super-secret-key \
    --from-literal=db_password=secure-password \
    --dry-run=client -o yaml | kubectl apply -f -

# Esperar a que los pods estén listos
print_status "Esperando a que los pods estén listos..."
kubectl wait --for=condition=ready pod --all --namespace=testing --timeout=300s || true
kubectl wait --for=condition=ready pod --all --namespace=production --timeout=300s || true

# Mostrar resumen
print_status "Configuración completada! Resumen del entorno:"
echo ""
echo "📊 Namespaces creados:"
kubectl get namespaces | grep -E "(testing|production|monitoring|cert-manager)"

echo ""
echo "🎯 Helm releases instalados:"
helm list --all-namespaces

echo ""
echo "🔧 Pods en ejecución:"
kubectl get pods --all-namespaces -o wide

echo ""
echo "📡 Servicios disponibles:"
kubectl get services --all-namespaces

echo ""
print_status "Comandos útiles para probar el MCP:"
echo "  npm run start                    - Iniciar el MCP server"
echo "  kubectl get pods --all-namespaces  - Ver todos los pods"
echo "  helm list --all-namespaces      - Ver releases de Helm"
echo "  minikube service list           - Ver servicios expuestos"
echo ""

print_status "Para acceder a los servicios web:"
echo "  minikube service nginx-test --namespace testing --url"
echo "  minikube service prometheus-kube-prometheus-prometheus --namespace monitoring --url"
echo "  minikube service prometheus-grafana --namespace monitoring --url"
echo "  minikube service argocd-server --namespace argocd --url"
echo ""

print_warning "Credenciales de Grafana:"
echo "  Usuario: admin"
echo "  Password: $(kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode 2>/dev/null || echo 'No disponible')"

print_warning "Credenciales de ArgoCD:"
echo "  Usuario: admin"
echo "  Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode 2>/dev/null || echo 'No disponible')"
echo "  URL Local: http://localhost:30080"