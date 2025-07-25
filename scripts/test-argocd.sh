#!/bin/bash

# Script específico para probar el MCP server con ArgoCD
set -e

echo "🧪 Probando MCP Server con ArgoCD..."

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Verificar prerrequisitos
print_status "Verificando prerrequisitos..."

if ! kubectl get namespace argocd &>/dev/null; then
    print_error "ArgoCD no está instalado. Ejecuta: ./scripts/setup-k8s.sh"
    exit 1
fi

if ! kubectl get deployment argocd-server -n argocd &>/dev/null; then
    print_error "ArgoCD server no encontrado"
    exit 1
fi

print_status "ArgoCD está instalado ✅"

# Verificar que ArgoCD esté corriendo
print_status "Verificando estado de ArgoCD..."
kubectl get pods -n argocd
echo ""

# Obtener información de conexión
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode 2>/dev/null || echo "No disponible")
ARGOCD_URL=$(minikube service argocd-server --namespace argocd --url 2>/dev/null | head -1 || echo "http://localhost:30080")

print_status "Credenciales de ArgoCD:"
echo "  URL: $ARGOCD_URL"
echo "  Usuario: admin"
echo "  Password: $ARGOCD_PASSWORD"
echo ""

# Crear aplicaciones de ejemplo en ArgoCD
print_status "Creando aplicaciones de ejemplo en ArgoCD..."

# App 1: Aplicación simple con Helm
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-app
  namespace: argocd
  labels:
    version: "1.24.0"
    type: "web-server"
spec:
  project: default
  source:
    repoURL: https://charts.bitnami.com/bitnami
    targetRevision: 15.4.4
    chart: nginx
    helm:
      parameters:
      - name: service.type
        value: NodePort
      - name: service.nodePorts.http
        value: "30081"
      - name: image.tag
        value: "1.24.0"
  destination:
    server: https://kubernetes.default.svc
    namespace: testing
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

# App 2: Aplicación con versión diferente
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: redis-app
  namespace: argocd
  labels:
    version: "7.2.0"
    type: "database"
spec:
  project: default
  source:
    repoURL: https://charts.bitnami.com/bitnami
    targetRevision: 18.1.5
    chart: redis
    helm:
      parameters:
      - name: auth.enabled
        value: "false"
      - name: master.persistence.enabled
        value: "false"
      - name: replica.replicaCount
        value: "1"
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

# App 3: Aplicación desactualizada (para testing de detección de versiones)
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: postgres-old
  namespace: argocd
  labels:
    version: "11.9.13"
    type: "database"
spec:
  project: default
  source:
    repoURL: https://charts.bitnami.com/bitnami
    targetRevision: 11.9.13
    chart: postgresql
    helm:
      parameters:
      - name: auth.postgresPassword
        value: "testpassword"
      - name: primary.persistence.enabled
        value: "false"
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

print_status "Aplicaciones de ArgoCD creadas ✅"

# Esperar sincronización
print_status "Esperando sincronización de aplicaciones (esto puede tomar unos minutos)..."
sleep 30

# Mostrar estado de las aplicaciones
print_status "Estado de las aplicaciones en ArgoCD:"
kubectl get applications -n argocd -o wide

echo ""
print_status "Aplicaciones por namespace:"
echo "Testing:"
kubectl get all -n testing | grep -E "(pod|service|deployment)" || echo "  Sin recursos"

echo ""
echo "Production:"
kubectl get all -n production | grep -E "(pod|service|deployment)" || echo "  Sin recursos"

echo ""
echo "Monitoring:"
kubectl get all -n monitoring | grep -E "(pod|service|deployment)" || echo "  Sin recursos"

echo ""
print_status "Helm releases (debería mostrar las apps gestionadas por ArgoCD):"
helm list --all-namespaces

echo ""
print_status "✅ Test de ArgoCD completado!"
echo ""
print_warning "Para probar el MCP server, ejecuta:"
echo "  npm run build && npm run start"
echo ""
print_warning "Y luego prueba estos comandos MCP:"
echo "  - list_applications"
echo "  - get_application_details"
echo "  - list_helm_releases"
echo "  - analyze_versions"