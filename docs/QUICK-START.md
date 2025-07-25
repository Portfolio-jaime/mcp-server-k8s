# 🔐 MCP Server HTTPS - Guía Rápida

## 🎯 Qué es esto

Un servidor MCP (Model Context Protocol) que permite a Claude Desktop interactuar con tu cluster de Kubernetes usando herramientas como `kubectl` y `helm`, ejecutándose completamente dentro de un devcontainer con HTTPS.

## ⚡ Inicio Rápido

### 1. **Abrir en DevContainer**
```bash
# En VS Code: Cmd+Shift+P → "Dev Containers: Reopen in Container"
```

### 2. **Iniciar el Servidor**
```bash
# En terminal del devcontainer
./scripts/start-mcp-http.sh
```

### 3. **Configurar Claude Desktop**
- URL: `https://localhost:3002/mcp`
- Nombre: "Kubernetes Tools"

## 🛠️ Herramientas Disponibles

| Herramienta | Descripción |
|-------------|-------------|
| `get_pods` | Lista pods del cluster |
| `get_helm_releases` | Lista releases de Helm |
| `get_cluster_info` | Información del cluster |
| `get_services` | Lista servicios |
| `get_namespaces` | Lista namespaces |

## 🧪 Verificar que Funciona

### **1. Health Check**
```bash
curl -k https://localhost:3002/health
```

### **2. Listar Herramientas**
```bash
curl -k -X POST https://localhost:3002/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}'
```

### **3. Probar Herramienta**
```bash
curl -k -X POST https://localhost:3002/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0", 
    "id": 1, 
    "method": "tools/call",
    "params": {
      "name": "get_pods",
      "arguments": {}
    }
  }'
```

### **4. En el Navegador**
- Ve a: `https://localhost:3002`
- Acepta la advertencia del certificado
- Deberías ver la página de información

## 🔧 Comandos Útiles

```bash
# Construir proyecto
npm run build

# Servidor HTTPS (recomendado)
npm run start:https

# Servidor HTTP (alternativo)
npm run start:http

# Desarrollo con auto-rebuild
npm run build:watch
```

## ⚠️ Certificados Self-Signed

El servidor usa certificados auto-generados para HTTPS:
- **Ubicación:** `./certs/`
- **Navegador:** Acepta "Proceed to localhost (unsafe)"
- **curl:** Usa flag `-k`

## 📊 URLs del Servidor

| Endpoint | URL | Descripción |
|----------|-----|-------------|
| MCP | `https://localhost:3002/mcp` | Endpoint principal para Claude Desktop |
| Info | `https://localhost:3002` | Página de información |
| Health | `https://localhost:3002/health` | Health check |

## 🐛 Problemas Comunes

### **Puerto ocupado**
```bash
PORT=3003 npm run start:https
```

### **Kubernetes no conecta**
```bash
kubectl cluster-info
kubectl get nodes
```

### **Claude Desktop no se conecta**
1. Verificar que el servidor esté corriendo
2. Confirmar URL: `https://localhost:3002/mcp`
3. Probar con curl primero

## 📚 Documentación Completa

Ver: [`docs/MCP-HTTPS-SETUP.md`](docs/MCP-HTTPS-SETUP.md)

## 🎉 Ejemplos de Uso en Claude Desktop

Una vez configurado, puedes preguntarle a Claude:

- "¿Qué pods tengo corriendo en mi cluster?"
- "Muéstrame los releases de Helm instalados"
- "Dame información general de mi cluster de Kubernetes"
- "Lista todos los namespaces disponibles"
- "¿Qué servicios tengo en el namespace default?"

## 🏗️ Arquitectura

```
Claude Desktop (macOS) ─HTTPS─> DevContainer (Docker) ─kubectl/helm─> Kubernetes Cluster
     Port 3002                      MCP Server                         (EKS/minikube)
```

---

**🔒 Nota de Seguridad:** Este setup está diseñado para desarrollo local. Para producción, usa certificados válidos y autenticación apropiada.