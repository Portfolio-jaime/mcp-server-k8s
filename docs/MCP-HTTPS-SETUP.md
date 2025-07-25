# 🔐 MCP Server HTTPS para Claude Desktop

## Descripción

Este documento describe la configuración completa de un servidor MCP (Model Context Protocol) con HTTPS para integrar herramientas de Kubernetes con Claude Desktop, ejecutándose completamente dentro de un devcontainer.

## 🏗️ Arquitectura

```
┌─────────────────┐    HTTPS    ┌──────────────────┐    kubectl/helm    ┌─────────────────┐
│   Claude        │◄────────────┤   DevContainer   │◄───────────────────┤  Kubernetes     │
│   Desktop       │  Port 3002  │   MCP Server     │                    │  Cluster        │
│   (Host macOS)  │             │   (Docker)       │                    │  (EKS/minikube) │
└─────────────────┘             └──────────────────┘                    └─────────────────┘
```

## 📁 Estructura del Proyecto

```
mcp-server-argocd/
├── src/
│   ├── https-server.ts          # Servidor HTTPS principal
│   ├── http-server-simple.ts    # Servidor HTTP alternativo
│   └── index.ts                 # Servidor MCP stdio original
├── scripts/
│   └── start-mcp-http.sh        # Script de inicio del servidor
├── .devcontainer/
│   ├── devcontainer.json        # Configuración VS Code DevContainer
│   ├── docker-compose.yml       # Orquestación de containers
│   ├── Dockerfile              # Imagen base con herramientas K8s
│   └── post-create.sh          # Setup post-creación
├── certs/                       # Certificados SSL (auto-generados)
│   ├── server.key              # Clave privada
│   └── server.crt              # Certificado público
└── docs/
    └── MCP-HTTPS-SETUP.md      # Este documento
```

## 🛠️ Componentes Principales

### 1. **Servidor HTTPS MCP**
- **Archivo:** `src/https-server.ts`
- **Puerto:** 3002
- **Protocol:** HTTPS con certificados self-signed
- **Endpoint principal:** `/mcp`
- **Health check:** `/health`

### 2. **DevContainer Configuration**
- **Puerto forward:** 3002:3002 (container → host)
- **Volúmenes:** Código fuente, configuraciones K8s, cache npm
- **Tools:** kubectl, helm, node, docker-in-docker

### 3. **Herramientas Kubernetes Disponibles**
- `get_pods` - Lista pods del cluster
- `get_helm_releases` - Lista releases de Helm
- `get_cluster_info` - Información general del cluster
- `get_services` - Lista servicios
- `get_namespaces` - Lista namespaces

## 🚀 Instalación y Configuración

### Prerequisitos
- Docker Desktop
- VS Code con extensión Dev Containers
- Acceso a un cluster Kubernetes (configurado en ~/.kube/config)

### Paso 1: Preparar el DevContainer
```bash
# Clonar el repositorio
git clone <repository-url>
cd mcp-server-argocd

# Abrir en VS Code
code .

# Reabrir en container: Cmd+Shift+P → "Dev Containers: Reopen in Container"
```

### Paso 2: Construir el Proyecto
```bash
# En terminal del devcontainer
npm install
npm run build
```

### Paso 3: Iniciar el Servidor HTTPS
```bash
# En terminal del devcontainer
./scripts/start-mcp-http.sh
```

### Paso 4: Configurar Claude Desktop
1. Abrir Claude Desktop
2. Ir a configuración de conectores
3. Agregar nuevo conector remoto
4. **URL:** `https://localhost:3002/mcp`
5. **Nombre:** "Kubernetes Tools"

## 🔧 Comandos Útiles

### Desarrollo
```bash
# Construir proyecto
npm run build

# Modo desarrollo (auto-rebuild)
npm run build:watch

# Iniciar servidor HTTPS
npm run start:https

# Iniciar servidor HTTP (alternativo)
npm run start:http
```

### Testing
```bash
# Health check
curl -k https://localhost:3002/health

# Listar herramientas MCP
curl -k -X POST https://localhost:3002/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}'

# Probar herramienta específica
curl -k -X POST https://localhost:3002/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0", 
    "id": 1, 
    "method": "tools/call",
    "params": {
      "name": "get_pods",
      "arguments": {"namespace": "default"}
    }
  }'
```

### Kubernetes
```bash
# Verificar conectividad
kubectl cluster-info
kubectl get nodes

# Ver recursos
kubectl get pods --all-namespaces
helm list --all-namespaces
```

## 🔐 Certificados SSL

### Generación Automática
Los certificados se generan automáticamente al iniciar el servidor:
- **Ubicación:** `./certs/`
- **Tipo:** Self-signed para localhost
- **Validez:** 365 días
- **Algoritmo:** RSA 2048 bits

### Estructura de Certificados
```bash
certs/
├── server.key  # Clave privada RSA
└── server.crt  # Certificado público X.509
```

### Comando de Generación
```bash
# Clave privada
openssl genrsa -out certs/server.key 2048

# Certificado
openssl req -new -x509 -key certs/server.key -out certs/server.crt -days 365 \
  -subj "/C=US/ST=Dev/L=Local/O=MCP/OU=DevContainer/CN=localhost"
```

## 🌐 Network Configuration

### Port Forwarding
```yaml
# docker-compose.yml
ports:
  - "3002:3002"  # MCP HTTPS Server

# devcontainer.json
"forwardPorts": [3002]
"portsAttributes": {
  "3002": {
    "label": "MCP HTTPS Server",
    "onAutoForward": "notify"
  }
}
```

### CORS Headers
```javascript
res.setHeader('Access-Control-Allow-Origin', '*');
res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
```

## 🐛 Troubleshooting

### Problemas Comunes

#### 1. **Error: EADDRINUSE (Puerto ocupado)**
```bash
# Verificar procesos en puerto 3002
lsof -i :3002

# Terminar proceso si es necesario
kill -9 <PID>

# O usar puerto alternativo
PORT=3003 npm run start:https
```

#### 2. **Certificado SSL Rechazado**
```bash
# En navegador: "Advanced" → "Proceed to localhost (unsafe)"
# En curl: usar flag -k
curl -k https://localhost:3002/health
```

#### 3. **kubectl/helm no encontrado**
```bash
# Verificar herramientas en devcontainer
which kubectl
which helm

# Reconstruir devcontainer si faltan
# Cmd+Shift+P → "Dev Containers: Rebuild Container"
```

#### 4. **No hay conectividad con Kubernetes**
```bash
# Verificar contexto
kubectl config current-context

# Verificar acceso
kubectl cluster-info
kubectl get nodes

# Si usas minikube en devcontainer
minikube status
minikube start --driver=docker
```

#### 5. **Claude Desktop no se conecta**
- Verificar que el servidor esté corriendo
- Confirmar URL: `https://localhost:3002/mcp`
- Revisar logs del servidor
- Probar endpoint manualmente con curl

### Logs y Debug

#### Logs del Servidor
```bash
# El servidor muestra logs en consola
./scripts/start-mcp-http.sh

# Logs típicos:
🔐 Generando certificados SSL self-signed...
✅ Certificados generados exitosamente
🔐 Kubernetes MCP HTTPS Server iniciado
📡 Puerto: 3002
🔗 URL para Claude Desktop: https://localhost:3002/mcp
```

#### Debug de Peticiones MCP
```bash
# El servidor logea todas las peticiones MCP
# Buscar en consola del servidor:
# - Método llamado (tools/list, tools/call)
# - Argumentos recibidos
# - Respuestas enviadas
# - Errores si los hay
```

## 📊 Monitoring y Performance

### Health Check
```bash
curl -k https://localhost:3002/health
```

**Respuesta esperada:**
```json
{
  "status": "healthy",
  "server": "k8s-versions-mcp-https",
  "version": "1.0.0",
  "protocol": "HTTPS",
  "timestamp": "2024-07-25T..."
}
```

### Métricas Básicas
- **Startup time:** ~2-3 segundos
- **Response time:** <100ms para operaciones simples
- **Memory usage:** ~50-100MB
- **CPU usage:** Mínimo en idle

## 🔒 Seguridad

### Consideraciones
- **Certificados self-signed:** Solo para desarrollo local
- **CORS abierto:** Permite conexiones desde cualquier origen
- **Sin autenticación:** El servidor no requiere tokens/API keys
- **Acceso local:** Solo accesible via localhost

### Para Producción
- Usar certificados firmados por CA
- Implementar autenticación (API keys, OAuth)
- Restringir CORS a dominios específicos
- Usar HTTPS con TLS 1.2+
- Implementar rate limiting

## 📚 Referencias

- [Model Context Protocol (MCP)](https://modelcontextprotocol.io/)
- [Claude Desktop](https://claude.ai/desktop)
- [VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)

## 📝 Changelog

### v1.0.0 (2024-07-25)
- ✅ Servidor HTTPS MCP implementado
- ✅ Integración con DevContainer
- ✅ Certificados self-signed automáticos
- ✅ Port forwarding configurado
- ✅ 5 herramientas Kubernetes disponibles
- ✅ Documentación completa