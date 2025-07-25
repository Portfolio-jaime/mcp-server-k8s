#!/bin/bash

# Script optimizado para probar el servidor MCP de Kubernetes
# Incluye pruebas de rendimiento, manejo de errores mejorado y validación de cache

set -e

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TIMEOUT_SECONDS=30
MAX_RETRIES=3
PERFORMANCE_THRESHOLD_MS=5000

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Contadores para estadísticas
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_perf() {
    echo -e "${PURPLE}[PERF]${NC} $1"
}

print_result() {
    local status="$1"
    local message="$2"
    
    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}[PASS]${NC} $message"
        ((TESTS_PASSED++))
    elif [ "$status" = "FAIL" ]; then
        echo -e "${RED}[FAIL]${NC} $message"
        ((TESTS_FAILED++))
    elif [ "$status" = "SKIP" ]; then
        echo -e "${YELLOW}[SKIP]${NC} $message"
        ((TESTS_SKIPPED++))
    fi
    ((TESTS_TOTAL++))
}

# Función para verificar dependencias
check_dependencies() {
    print_status "Verificando dependencias..."
    
    local missing_deps=()
    
    if ! command -v kubectl &> /dev/null; then
        missing_deps+=("kubectl")
    fi
    
    if ! command -v helm &> /dev/null; then
        missing_deps+=("helm")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if ! command -v node &> /dev/null; then
        missing_deps+=("node")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Dependencias faltantes: ${missing_deps[*]}"
        print_error "Instala las dependencias faltantes antes de ejecutar las pruebas"
        exit 1
    fi
    
    print_status "✅ Todas las dependencias están disponibles"
}

# Función para verificar conectividad con Kubernetes
check_k8s_connectivity() {
    print_status "Verificando conectividad con Kubernetes..."
    
    if ! kubectl cluster-info &> /dev/null; then
        print_warning "No se puede conectar al cluster de Kubernetes"
        print_warning "Algunas pruebas serán omitidas"
        return 1
    fi
    
    # Verificar que minikube esté corriendo si está disponible
    if command -v minikube &> /dev/null; then
        if ! minikube status &> /dev/null; then
            print_warning "Minikube no está corriendo. Iniciando..."
            if ! minikube start --driver=docker --memory=4096 --cpus=2; then
                print_error "No se pudo iniciar minikube"
                return 1
            fi
        fi
    fi
    
    print_status "✅ Conectividad con Kubernetes verificada"
    return 0
}

# Función mejorada para probar comandos MCP
test_mcp_command() {
    local test_name="$1"
    local tool_name="$2"
    local args="$3"
    local expected_fields="$4"  # JSON path para validar campos esperados
    local should_succeed="${5:-true}"
    
    print_test "Ejecutando: $test_name"
    
    # Crear mensaje JSON para MCP
    local request=$(cat <<EOF
{
  "jsonrpc": "2.0",
  "id": $(date +%s),
  "method": "tools/call",
  "params": {
    "name": "$tool_name",
    "arguments": $args
  }
}
EOF
)
    
    local start_time=$(date +%s%3N)
    local temp_file=$(mktemp)
    local error_file=$(mktemp)
    
    # Ejecutar comando con timeout
    if timeout "$TIMEOUT_SECONDS" bash -c "echo '$request' | node '$PROJECT_DIR/dist/index-optimized.js' > '$temp_file' 2> '$error_file'"; then
        local end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))
        
        print_perf "Duración: ${duration}ms"
        
        # Verificar que la respuesta sea JSON válido
        if ! jq empty "$temp_file" 2>/dev/null; then
            print_result "FAIL" "$test_name - Respuesta no es JSON válido"
            cat "$error_file"
            rm -f "$temp_file" "$error_file"
            return 1
        fi
        
        # Verificar si hay errores en la respuesta
        local has_error=$(jq -r '.error // false' "$temp_file")
        local is_error=$(jq -r '.isError // false' "$temp_file")
        
        if [ "$should_succeed" = "true" ]; then
            if [ "$has_error" != "false" ] || [ "$is_error" = "true" ]; then
                print_result "FAIL" "$test_name - Error en respuesta MCP"
                jq '.error // .content[0].text' "$temp_file"
                rm -f "$temp_file" "$error_file"
                return 1
            fi
        fi
        
        # Validar campos esperados si se proporcionan
        if [ -n "$expected_fields" ]; then
            if ! jq -e "$expected_fields" "$temp_file" > /dev/null 2>&1; then
                print_result "FAIL" "$test_name - Campos esperados no encontrados: $expected_fields"
                rm -f "$temp_file" "$error_file"
                return 1
            fi
        fi
        
        # Verificar rendimiento
        if [ "$duration" -gt "$PERFORMANCE_THRESHOLD_MS" ]; then
            print_warning "Rendimiento: ${duration}ms (excede umbral de ${PERFORMANCE_THRESHOLD_MS}ms)"
        fi
        
        print_result "PASS" "$test_name (${duration}ms)"
        
        # Mostrar muestra de la respuesta si es pequeña
        local response_size=$(wc -c < "$temp_file")
        if [ "$response_size" -lt 1000 ]; then
            echo -e "${CYAN}Respuesta:${NC}"
            jq -C '.' "$temp_file" | head -20
        else
            echo -e "${CYAN}Respuesta: ${response_size} bytes${NC}"
        fi
        
        rm -f "$temp_file" "$error_file"
        return 0
    else
        print_result "FAIL" "$test_name - Timeout o error de ejecución"
        if [ -s "$error_file" ]; then
            cat "$error_file"
        fi
        rm -f "$temp_file" "$error_file"
        return 1
    fi
}

# Función para probar el rendimiento del cache
test_cache_performance() {
    print_test "Probando rendimiento del cache"
    
    local cache_test_args='{"namespace": "default"}'
    
    # Primera llamada (sin cache)
    local start1=$(date +%s%3N)
    test_mcp_command "Cache Miss" "get_pods" "$cache_test_args" ".data" "true" > /dev/null 2>&1
    local end1=$(date +%s%3N)
    local duration1=$((end1 - start1))
    
    # Segunda llamada (con cache)
    local start2=$(date +%s%3N)
    test_mcp_command "Cache Hit" "get_pods" "$cache_test_args" ".data" "true" > /dev/null 2>&1
    local end2=$(date +%s%3N)
    local duration2=$((end2 - start2))
    
    print_perf "Cache Miss: ${duration1}ms, Cache Hit: ${duration2}ms"
    
    # El cache hit debería ser significativamente más rápido
    if [ "$duration2" -lt "$((duration1 / 2))" ]; then
        print_result "PASS" "Cache funcionando correctamente (${duration2}ms vs ${duration1}ms)"
    else
        print_result "FAIL" "Cache no parece estar funcionando (${duration2}ms vs ${duration1}ms)"
    fi
}

# Función para probar manejo de errores
test_error_handling() {
    print_test "Probando manejo de errores"
    
    # Test con namespace inexistente
    test_mcp_command "Namespace inexistente" "get_pods" '{"namespace": "nonexistent-namespace-12345"}' ".data" "true"
    
    # Test con herramienta inexistente
    local request='{"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": "nonexistent_tool", "arguments": {}}}'
    echo "$request" | timeout 10 node "$PROJECT_DIR/dist/index-optimized.js" | jq '.error' | grep -q "Herramienta desconocida" && \
        print_result "PASS" "Manejo de herramienta inexistente" || \
        print_result "FAIL" "Manejo de herramienta inexistente"
    
    # Test con argumentos inválidos
    test_mcp_command "Argumentos inválidos" "compare_versions" '{"component": ""}' "" "false"
}

# Función para mostrar estadísticas finales
show_final_stats() {
    echo ""
    echo "================================="
    echo -e "${CYAN}RESUMEN DE PRUEBAS${NC}"
    echo "================================="
    echo -e "Total:    ${TESTS_TOTAL}"
    echo -e "Pasaron:  ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Fallaron: ${RED}${TESTS_FAILED}${NC}"
    echo -e "Omitidas: ${YELLOW}${TESTS_SKIPPED}${NC}"
    
    local success_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    echo -e "Tasa de éxito: ${success_rate}%"
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}🎉 ¡Todas las pruebas pasaron!${NC}"
        return 0
    else
        echo -e "${RED}❌ Algunas pruebas fallaron${NC}"
        return 1
    fi
}

# Función principal
main() {
    echo "🧪 Iniciando suite de pruebas optimizada del MCP Server"
    echo "======================================================"
    
    # Verificar dependencias
    check_dependencies
    
    # Verificar construcción del proyecto
    cd "$PROJECT_DIR"
    if [ ! -d "dist" ] || [ ! -f "dist/index-optimized.js" ]; then
        print_status "Construyendo proyecto..."
        npm run build || {
            print_error "No se pudo construir el proyecto"
            exit 1
        }
    fi
    
    # Verificar conectividad K8s
    local k8s_available=true
    if ! check_k8s_connectivity; then
        k8s_available=false
    fi
    
    echo ""
    print_status "Iniciando pruebas funcionales..."
    
    # Test 1: Listar herramientas disponibles
    print_test "Listando herramientas disponibles"
    local tools_request='{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}'
    if echo "$tools_request" | timeout 10 node dist/index-optimized.js | jq -e '.result.tools | length > 0' > /dev/null; then
        local tool_count=$(echo "$tools_request" | node dist/index-optimized.js | jq -r '.result.tools | length')
        print_result "PASS" "Herramientas disponibles: $tool_count"
    else
        print_result "FAIL" "No se pudieron listar las herramientas"
    fi
    
    if [ "$k8s_available" = "true" ]; then
        # Test 2: Información del cluster
        test_mcp_command "Información del cluster" "get_cluster_info" "{}" ".data.version"
        
        # Test 3: Pods - todos los namespaces
        test_mcp_command "Pods (todos los namespaces)" "get_pods" "{}" ".data"
        
        # Test 4: Pods - namespace específico
        test_mcp_command "Pods (namespace testing)" "get_pods" '{"namespace": "testing"}' ".data"
        
        # Test 5: Servicios
        test_mcp_command "Servicios" "get_services" "{}" ".data"
        
        # Test 6: Releases de Helm
        test_mcp_command "Releases de Helm" "get_helm_releases" "{}" ".data"
        
        # Test 7: Repositorios de Helm
        test_mcp_command "Repositorios de Helm" "get_repositories" "{}" ".data"
        
        # Test 8: Análisis de versiones
        test_mcp_command "Análisis de versiones" "analyze_versions" "{}" ".data.components"
        
        # Test 9: Componentes desactualizados
        test_mcp_command "Componentes desactualizados" "get_outdated_components" "{}" ".data"
        
        # Test 10: Comparar versiones
        test_mcp_command "Comparar versiones" "compare_versions" '{
            "component": "nginx",
            "currentVersion": "1.20.2",
            "targetVersion": "1.25.3"
        }' ".data.comparison"
        
        # Test 11: Estadísticas de cache
        test_mcp_command "Estadísticas de cache" "get_cache_stats" "{}" ".data"
        
        # Test 12: Limpiar cache
        test_mcp_command "Limpiar cache" "clear_cache" '{"service": "all"}' ".success"
        
        # Pruebas de rendimiento
        print_status "Ejecutando pruebas de rendimiento..."
        test_cache_performance
        
    else
        print_result "SKIP" "Pruebas de Kubernetes (cluster no disponible)"
    fi
    
    # Pruebas de manejo de errores
    print_status "Ejecutando pruebas de manejo de errores..."
    test_error_handling
    
    # Mostrar estadísticas del cluster si está disponible
    if [ "$k8s_available" = "true" ]; then
        echo ""
        print_status "📊 Estadísticas del cluster actual:"
        echo "Namespaces: $(kubectl get namespaces --no-headers 2>/dev/null | wc -l || echo "N/A")"
        echo "Pods total: $(kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l || echo "N/A")"
        echo "Helm releases: $(helm list --all-namespaces --short 2>/dev/null | wc -l || echo "N/A")"
        echo "Servicios: $(kubectl get services --all-namespaces --no-headers 2>/dev/null | wc -l || echo "N/A")"
    fi
    
    # Mostrar estadísticas finales
    show_final_stats
}

# Manejo de señales para cleanup
cleanup() {
    print_warning "Interrupción detectada, limpiando..."
    exit 130
}

trap cleanup SIGINT SIGTERM

# Ejecutar función principal
main "$@"