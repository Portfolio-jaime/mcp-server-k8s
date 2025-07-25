# Configuration Guide

## Overview

The K8s Versions MCP Server supports comprehensive configuration through environment variables, configuration files, or programmatic updates. This guide covers all available configuration options and best practices.

## Configuration Methods

### 1. Environment Variables

The most common method for production deployments.

```bash
# Server Configuration
export MCP_SERVER_NAME="k8s-versions-mcp-production"
export MCP_SERVER_VERSION="2.0.0"
export MCP_SERVER_TIMEOUT=30000

# Kubernetes Configuration
export K8S_TIMEOUT=30000
export K8S_RETRIES=3
export K8S_RETRY_DELAY=1000

# Helm Configuration
export HELM_TIMEOUT=45000
export HELM_RETRIES=3
export HELM_RETRY_DELAY=1000
export HELM_AUTO_UPDATE_REPOS=true

# Cache Configuration
export CACHE_DEFAULT_TTL=300

# Logging Configuration
export LOG_LEVEL=INFO
export LOG_PERFORMANCE=true
export LOG_CACHE=false

# Performance Configuration
export MAX_CONCURRENT_REQUESTS=10
export REQUEST_THRESHOLD_MS=5000
export ENABLE_METRICS=true

# Security Configuration
export ENABLE_INPUT_VALIDATION=true
export MAX_REQUEST_SIZE=1048576
export ENABLE_RATE_LIMIT=false
export RATE_LIMIT_WINDOW=60000
export RATE_LIMIT_MAX=100
```

### 2. Configuration File

Create a `config.json` file in the project root:

```json
{
  "server": {
    "name": "k8s-versions-mcp-optimized",
    "version": "2.0.0",
    "timeout": 30000
  },
  "kubernetes": {
    "timeout": 30000,
    "retries": 3,
    "retryDelay": 1000
  },
  "helm": {
    "timeout": 45000,
    "retries": 3,
    "retryDelay": 1000,
    "autoUpdateRepos": false
  },
  "cache": {
    "defaultTtl": 300,
    "pods": {
      "ttl": 60
    },
    "services": {
      "ttl": 60
    },
    "releases": {
      "ttl": 60
    },
    "clusterInfo": {
      "ttl": 180
    },
    "repositories": {
      "ttl": 300
    },
    "chartVersions": {
      "ttl": 900
    },
    "analysis": {
      "ttl": 1800
    }
  },
  "logging": {
    "level": "INFO",
    "enablePerformanceLogging": true,
    "enableCacheLogging": false
  },
  "performance": {
    "maxConcurrentRequests": 10,
    "requestThresholdMs": 5000,
    "enableMetrics": true
  },
  "security": {
    "enableInputValidation": true,
    "maxRequestSize": 1048576,
    "enableRateLimit": false,
    "rateLimitWindow": 60000,
    "rateLimitMax": 100
  }
}
```

You can also specify a custom config file path:

```bash
export MCP_CONFIG_PATH="/path/to/custom/config.json"
```

## Configuration Sections

### Server Configuration

Controls basic server behavior.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `name` | string | `"k8s-versions-mcp-optimized"` | Server identification name |
| `version` | string | `"2.0.0"` | Server version |
| `timeout` | number | `30000` | Global timeout in milliseconds |

### Kubernetes Configuration

Controls interaction with Kubernetes API.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `timeout` | number | `30000` | kubectl command timeout (ms) |
| `retries` | number | `3` | Number of retry attempts |
| `retryDelay` | number | `1000` | Delay between retries (ms) |

### Helm Configuration

Controls Helm operations.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `timeout` | number | `45000` | Helm command timeout (ms) |
| `retries` | number | `3` | Number of retry attempts |
| `retryDelay` | number | `1000` | Delay between retries (ms) |
| `autoUpdateRepos` | boolean | `false` | Auto-update repos before operations |

### Cache Configuration

Fine-tune caching behavior for optimal performance.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `defaultTtl` | number | `300` | Default cache TTL in seconds |
| `pods.ttl` | number | `60` | Pod data cache TTL |
| `services.ttl` | number | `60` | Service data cache TTL |
| `releases.ttl` | number | `60` | Helm releases cache TTL |
| `clusterInfo.ttl` | number | `180` | Cluster info cache TTL |
| `repositories.ttl` | number | `300` | Helm repositories cache TTL |
| `chartVersions.ttl` | number | `900` | Chart versions cache TTL |
| `analysis.ttl` | number | `1800` | Version analysis cache TTL |

### Logging Configuration

Control logging behavior and verbosity.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `level` | enum | `"INFO"` | Log level: ERROR, WARN, INFO, DEBUG |
| `enablePerformanceLogging` | boolean | `true` | Log performance metrics |
| `enableCacheLogging` | boolean | `false` | Log cache operations |

### Performance Configuration

Optimize server performance.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `maxConcurrentRequests` | number | `10` | Maximum concurrent operations |
| `requestThresholdMs` | number | `5000` | Performance warning threshold |
| `enableMetrics` | boolean | `true` | Enable performance metrics |

### Security Configuration

Configure security features.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enableInputValidation` | boolean | `true` | Validate all inputs with Zod |
| `maxRequestSize` | number | `1048576` | Maximum request size (bytes) |
| `enableRateLimit` | boolean | `false` | Enable rate limiting |
| `rateLimitWindow` | number | `60000` | Rate limit window (ms) |
| `rateLimitMax` | number | `100` | Max requests per window |

## Environment-Specific Configurations

### Development

```bash
export LOG_LEVEL=DEBUG
export LOG_PERFORMANCE=true
export LOG_CACHE=true
export CACHE_DEFAULT_TTL=60
export ENABLE_METRICS=true
```

### Production

```bash
export LOG_LEVEL=INFO
export LOG_PERFORMANCE=false
export LOG_CACHE=false
export CACHE_DEFAULT_TTL=300
export ENABLE_RATE_LIMIT=true
export RATE_LIMIT_MAX=200
export MAX_CONCURRENT_REQUESTS=20
```

### High-Traffic Environment

```bash
export CACHE_DEFAULT_TTL=600
export MAX_CONCURRENT_REQUESTS=25
export REQUEST_THRESHOLD_MS=3000
export K8S_TIMEOUT=15000
export HELM_TIMEOUT=30000
```

## Configuration Validation

The server validates all configuration on startup. Invalid configurations will prevent the server from starting:

```bash
npm start
# Output:
# [ERROR] Configuration validation failed: kubernetes.timeout must be at least 1000
```

## Runtime Configuration Updates

Some configuration can be updated at runtime (requires implementing admin endpoints):

```typescript
import { config } from './src/config/config.js';

// Update cache TTL
config.updateConfig({
  cache: {
    defaultTtl: 600
  }
});
```

## Environment Validation

The server can validate the environment on startup:

```typescript
import { config } from './src/config/config.js';

const validation = config.validateEnvironment();
if (!validation.valid) {
  console.error('Environment validation failed:', validation.errors);
  process.exit(1);
}
```

## Configuration File Generation

Generate a default configuration file:

```bash
node -e "
import { createDefaultConfigFile } from './dist/config/config.js';
createDefaultConfigFile('./config.json');
"
```

## Best Practices

### 1. Environment Separation

Use different configurations for different environments:

```bash
# config/development.json
# config/production.json
# config/staging.json

export MCP_CONFIG_PATH="./config/production.json"
```

### 2. Security

- Never commit sensitive configuration to version control
- Use environment variables for secrets
- Enable input validation in production
- Consider enabling rate limiting for public deployments

### 3. Performance Tuning

- Start with default values
- Monitor performance metrics
- Adjust cache TTL based on data volatility
- Increase timeouts for slow clusters
- Tune concurrent requests based on cluster capacity

### 4. Monitoring

- Enable performance logging in development
- Disable verbose logging in production
- Monitor cache hit rates
- Track request durations

### 5. Cache Strategy

- Short TTL (60s) for frequently changing data (pods, services)
- Medium TTL (300s) for relatively stable data (repositories)
- Long TTL (1800s) for expensive operations (version analysis)

## Troubleshooting

### Common Issues

1. **Server won't start**
   - Check configuration validation errors
   - Verify all required tools are installed
   - Test Kubernetes connectivity

2. **Poor performance**
   - Check cache hit rates
   - Adjust timeout values
   - Monitor concurrent request limits

3. **Memory issues**
   - Reduce cache TTL values
   - Lower maxConcurrentRequests
   - Enable cache size monitoring

### Debug Configuration

```bash
export LOG_LEVEL=DEBUG
export LOG_CACHE=true
export LOG_PERFORMANCE=true
```

This will provide detailed logs about configuration loading and runtime behavior.