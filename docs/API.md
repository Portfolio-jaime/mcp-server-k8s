# K8s Versions MCP Server - API Documentation

## Overview

The K8s Versions MCP Server provides a comprehensive set of tools for monitoring and analyzing Kubernetes cluster components and their versions through the Model Context Protocol (MCP).

## Available Tools

### 1. `get_pods`

Retrieves detailed information about pods in the Kubernetes cluster.

**Parameters:**
- `namespace` (optional): Specific namespace to query
- `selector` (optional): Label selector to filter pods

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "name": "nginx-deployment-7d5d5c6b4f-abc123",
      "namespace": "default",
      "status": "Running",
      "ready": "1/1",
      "restarts": 0,
      "age": "2d",
      "node": "worker-node-1",
      "images": ["nginx:1.21.0"],
      "labels": {
        "app": "nginx",
        "version": "1.21.0"
      },
      "annotations": {},
      "resources": {
        "requests": {
          "cpu": "100m",
          "memory": "128Mi"
        },
        "limits": {
          "cpu": "500m",
          "memory": "512Mi"
        }
      }
    }
  ],
  "metadata": {
    "count": 1,
    "namespace": "default",
    "selector": "app=nginx",
    "timestamp": "2024-01-15T10:30:00.000Z"
  }
}
```

**Example Usage:**
```bash
# Get all pods
echo '{"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": "get_pods", "arguments": {}}}' | node dist/index-optimized.js

# Get pods in specific namespace
echo '{"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": "get_pods", "arguments": {"namespace": "production"}}}' | node dist/index-optimized.js

# Get pods with label selector
echo '{"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": "get_pods", "arguments": {"selector": "app=nginx"}}}' | node dist/index-optimized.js
```

### 2. `get_services`

Retrieves information about Kubernetes services.

**Parameters:**
- `namespace` (optional): Specific namespace to query

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "name": "nginx-service",
      "namespace": "default",
      "type": "ClusterIP",
      "clusterIP": "10.96.0.100",
      "externalIP": "None",
      "ports": [
        {
          "name": "http",
          "port": 80,
          "targetPort": 8080,
          "protocol": "TCP"
        }
      ],
      "age": "2d",
      "selector": {
        "app": "nginx"
      }
    }
  ],
  "metadata": {
    "count": 1,
    "namespace": "default",
    "timestamp": "2024-01-15T10:30:00.000Z"
  }
}
```

### 3. `get_helm_releases`

Retrieves detailed information about Helm releases.

**Parameters:**
- `namespace` (optional): Specific namespace to query
- `status` (optional): Filter by release status (deployed, failed, etc.)

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "name": "nginx-release",
      "namespace": "default",
      "revision": 1,
      "updated": "2024-01-15T08:00:00Z",
      "status": "deployed",
      "chart": "nginx-15.4.4",
      "appVersion": "1.21.0",
      "description": "Install complete",
      "values": {
        "replicaCount": 2,
        "image": {
          "tag": "1.21.0"
        }
      },
      "history": [
        {
          "revision": 1,
          "updated": "2024-01-15T08:00:00Z",
          "status": "deployed",
          "chart": "nginx-15.4.4",
          "appVersion": "1.21.0",
          "description": "Install complete"
        }
      ]
    }
  ],
  "metadata": {
    "count": 1,
    "namespace": "default",
    "status": "all",
    "timestamp": "2024-01-15T10:30:00.000Z"
  }
}
```

### 4. `get_repositories`

Lists configured Helm repositories.

**Parameters:** None

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "name": "bitnami",
      "url": "https://charts.bitnami.com/bitnami",
      "status": "active"
    },
    {
      "name": "stable",
      "url": "https://charts.helm.sh/stable",
      "status": "active"
    }
  ],
  "metadata": {
    "count": 2,
    "timestamp": "2024-01-15T10:30:00.000Z"
  }
}
```

### 5. `get_cluster_info`

Provides comprehensive cluster information.

**Parameters:** None

**Response:**
```json
{
  "success": true,
  "data": {
    "version": "v1.28.3",
    "nodes": [
      {
        "name": "master-node",
        "status": "Ready",
        "roles": ["control-plane"],
        "age": "30d",
        "version": "v1.28.3",
        "os": "linux Ubuntu 22.04.3 LTS",
        "kernel": "5.15.0-91-generic",
        "containerRuntime": "containerd://1.7.0",
        "capacity": {
          "cpu": "4",
          "memory": "8Gi"
        },
        "allocatable": {
          "cpu": "3800m",
          "memory": "7Gi"
        }
      }
    ],
    "namespaces": ["default", "kube-system", "production"],
    "totalPods": 25,
    "totalServices": 12
  },
  "metadata": {
    "timestamp": "2024-01-15T10:30:00.000Z"
  }
}
```

### 6. `analyze_versions`

Performs comprehensive version analysis with security alerts and recommendations.

**Parameters:**
- `namespace` (optional): Specific namespace to analyze
- `component` (optional): Specific component to analyze

**Response:**
```json
{
  "success": true,
  "data": {
    "namespace": "all",
    "components": [
      {
        "name": "nginx-deployment",
        "type": "helm-release",
        "currentVersion": "15.4.4",
        "latestVersion": "15.5.1",
        "status": "outdated",
        "namespace": "default",
        "severity": "medium",
        "updateAvailable": true,
        "securityIssues": [],
        "lastChecked": "2024-01-15T10:30:00.000Z",
        "versionAge": 45,
        "supportStatus": "supported"
      }
    ],
    "summary": {
      "total": 15,
      "outdated": 3,
      "upToDate": 10,
      "unknown": 2,
      "critical": 0,
      "high": 1,
      "medium": 2,
      "low": 12
    },
    "recommendations": [
      "⚠️ 3 componente(s) están desactualizados y deberían ser actualizados",
      "📈 Considera actualizar los releases de Helm usando 'helm upgrade'"
    ],
    "securityAlerts": [
      {
        "component": "old-nginx",
        "severity": "high",
        "description": "Component is using a deprecated version with known vulnerabilities"
      }
    ],
    "performanceMetrics": {
      "analysisTime": 2500,
      "componentsAnalyzed": 15,
      "cacheHitRate": 0.6,
      "errors": []
    }
  },
  "metadata": {
    "timestamp": "2024-01-15T10:30:00.000Z"
  }
}
```

### 7. `compare_versions`

Compares two versions with detailed analysis and migration guidance.

**Parameters:**
- `component` (required): Component name
- `currentVersion` (required): Current version
- `targetVersion` (required): Target version

**Response:**
```json
{
  "success": true,
  "data": {
    "component": "nginx",
    "currentVersion": "1.20.2",
    "targetVersion": "1.25.3",
    "comparison": "older",
    "recommendation": "✅ Actualización recomendada de 1.20.2 a 1.25.3 para obtener mejoras y parches de seguridad",
    "breakingChanges": [
      "Cambio de versión mayor detectado (1.20.2 → 1.25.3)",
      "Posibles cambios incompatibles en la API",
      "Revisa la documentación de migración del componente"
    ],
    "migrationSteps": [
      "1. Realizar backup completo del estado actual y configuraciones",
      "2. Probar la actualización en un entorno de desarrollo/staging",
      "3. Revisar logs y métricas post-actualización",
      "4. Documentar cambios realizados",
      "5. Programar ventana de mantenimiento si es necesario",
      "6. Preparar plan de rollback en caso de problemas",
      "7. Ejecutar la actualización paso a paso",
      "8. Verificar funcionalidad crítica",
      "9. Monitorear por posibles problemas durante 24-48 horas",
      "10. Actualizar documentación y runbooks"
    ],
    "estimatedEffort": "medium",
    "riskLevel": "medium"
  },
  "metadata": {
    "timestamp": "2024-01-15T10:30:00.000Z"
  }
}
```

### 8. `get_outdated_components`

Retrieves components that need updates, prioritized by severity.

**Parameters:**
- `namespace` (optional): Specific namespace to check

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "name": "critical-app",
      "type": "helm-release",
      "currentVersion": "1.0.0",
      "latestVersion": "3.0.0",
      "status": "outdated",
      "namespace": "production",
      "severity": "critical",
      "updateAvailable": true,
      "securityIssues": [
        "Critical security vulnerability CVE-2023-12345",
        "Component is end-of-life and no longer receives updates"
      ],
      "supportStatus": "end-of-life"
    }
  ],
  "metadata": {
    "count": 1,
    "namespace": "all",
    "timestamp": "2024-01-15T10:30:00.000Z"
  }
}
```

### 9. `clear_cache`

Clears cache for improved performance management.

**Parameters:**
- `service` (optional): Specific service cache to clear ("kubernetes", "helm", "version-analyzer", "all")

**Response:**
```json
{
  "success": true,
  "message": "Cache cleared for service: all",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### 10. `get_cache_stats`

Provides cache performance statistics for monitoring.

**Parameters:** None

**Response:**
```json
{
  "success": true,
  "data": {
    "kubernetes": {
      "size": 5
    },
    "helm": {
      "size": 3
    },
    "versionAnalyzer": {
      "cacheSize": 2,
      "analysisCacheSize": 1,
      "k8sServiceCache": 5,
      "helmServiceCache": 3
    }
  },
  "metadata": {
    "timestamp": "2024-01-15T10:30:00.000Z"
  }
}
```

## Error Handling

All tools return consistent error responses:

```json
{
  "content": [
    {
      "type": "text",
      "text": "Error ejecutando get_pods: Connection to Kubernetes cluster failed"
    }
  ],
  "isError": true
}
```

## Performance Considerations

- **Caching**: All data is cached with configurable TTL to improve performance
- **Timeouts**: Commands have configurable timeouts to prevent hanging
- **Concurrency**: Parallel execution where possible to improve response times
- **Resource Management**: Automatic cleanup and memory management

## Configuration

The server can be configured through environment variables or a configuration file. See [Configuration Guide](./CONFIGURATION.md) for details.

## Rate Limiting

Optional rate limiting can be enabled to prevent abuse:
- Default: 100 requests per minute per client
- Configurable through environment variables

## Security

- Input validation using Zod schemas
- Command injection prevention
- Configurable request size limits
- Optional authentication hooks