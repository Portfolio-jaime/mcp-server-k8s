# Usage Examples

This document provides practical examples of using the K8s Versions MCP Server.

## Basic Usage Examples

### 1. Getting Started - Cluster Overview

```bash
# Build the project
npm run build

# Start the server
npm start

# In another terminal, get basic cluster information
echo '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "get_cluster_info",
    "arguments": {}
  }
}' | node dist/index-optimized.js | jq '.'
```

### 2. Pod Management Examples

#### Get all pods across namespaces
```bash
echo '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "get_pods",
    "arguments": {}
  }
}' | node dist/index-optimized.js | jq '.result.content[0].text | fromjson | .data'
```

#### Get pods in specific namespace
```bash
echo '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "get_pods",
    "arguments": {
      "namespace": "kube-system"
    }
  }
}' | node dist/index-optimized.js | jq '.result.content[0].text | fromjson | .data'
```

#### Filter pods by label
```bash
echo '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "get_pods",
    "arguments": {
      "selector": "app=nginx"
    }
  }
}' | node dist/index-optimized.js | jq '.result.content[0].text | fromjson | .data'
```

### 3. Helm Release Management

#### List all Helm releases
```bash
echo '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "get_helm_releases",
    "arguments": {}
  }
}' | node dist/index-optimized.js | jq '.result.content[0].text | fromjson | .data'
```

#### Get releases by status
```bash
echo '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "get_helm_releases",
    "arguments": {
      "status": "deployed"
    }
  }
}' | node dist/index-optimized.js | jq '.result.content[0].text | fromjson | .data'
```

#### List Helm repositories
```bash
echo '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "get_repositories",
    "arguments": {}
  }
}' | node dist/index-optimized.js | jq '.result.content[0].text | fromjson | .data'
```

### 4. Version Analysis Examples

#### Comprehensive version analysis
```bash
echo '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "analyze_versions",
    "arguments": {}
  }
}' | node dist/index-optimized.js | jq '.result.content[0].text | fromjson | .data'
```

#### Analyze specific namespace
```bash
echo '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "analyze_versions",
    "arguments": {
      "namespace": "production"
    }
  }
}' | node dist/index-optimized.js | jq '.result.content[0].text | fromjson | .data'
```

#### Get only outdated components
```bash
echo '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "get_outdated_components",
    "arguments": {}
  }
}' | node dist/index-optimized.js | jq '.result.content[0].text | fromjson | .data'
```

#### Compare specific versions
```bash
echo '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "compare_versions",
    "arguments": {
      "component": "nginx",
      "currentVersion": "1.20.2",
      "targetVersion": "1.25.3"
    }
  }
}' | node dist/index-optimized.js | jq '.result.content[0].text | fromjson | .data'
```

## Advanced Scripting Examples

### 1. Monitor Critical Components

```bash
#!/bin/bash
# monitor-critical.sh

echo "🔍 Monitoring critical components..."

# Get outdated components
OUTDATED=$(echo '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "get_outdated_components",
    "arguments": {"namespace": "production"}
  }
}' | node dist/index-optimized.js | jq -r '.result.content[0].text | fromjson | .data')

# Check if any critical components found
CRITICAL_COUNT=$(echo "$OUTDATED" | jq '[.[] | select(.severity == "critical")] | length')

if [ "$CRITICAL_COUNT" -gt 0 ]; then
  echo "🚨 ALERT: $CRITICAL_COUNT critical components found!"
  echo "$OUTDATED" | jq '[.[] | select(.severity == "critical")]'
  exit 1
else
  echo "✅ No critical components found"
fi
```

### 2. Generate Update Report

```bash
#!/bin/bash
# update-report.sh

NAMESPACE=${1:-"all"}
OUTPUT_FILE="update-report-$(date +%Y%m%d).json"

echo "📊 Generating update report for namespace: $NAMESPACE"

# Perform comprehensive analysis
ANALYSIS=$(echo '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "analyze_versions",
    "arguments": {"namespace": "'${NAMESPACE}'"}
  }
}' | node dist/index-optimized.js | jq '.result.content[0].text | fromjson')

# Save to file
echo "$ANALYSIS" > "$OUTPUT_FILE"

# Display summary
echo "Summary:"
echo "$ANALYSIS" | jq '.data.summary'

echo "Recommendations:"
echo "$ANALYSIS" | jq -r '.data.recommendations[]'

echo "📄 Full report saved to: $OUTPUT_FILE"
```

### 3. Cache Performance Monitor

```bash
#!/bin/bash
# cache-monitor.sh

echo "📈 Cache Performance Monitor"

while true; do
  STATS=$(echo '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "get_cache_stats",
      "arguments": {}
    }
  }' | node dist/index-optimized.js | jq '.result.content[0].text | fromjson | .data')
  
  clear
  echo "=== Cache Statistics ==="
  echo "Timestamp: $(date)"
  echo "$STATS" | jq '.'
  
  sleep 30
done
```

## Integration Examples

### 1. GitHub Actions Workflow

```yaml
# .github/workflows/k8s-version-check.yml
name: K8s Version Check

on:
  schedule:
    - cron: '0 9 * * 1'  # Every Monday at 9 AM
  workflow_dispatch:

jobs:
  version-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          
      - name: Install dependencies
        run: npm ci
        
      - name: Build project
        run: npm run build
        
      - name: Setup kubectl
        uses: azure/setup-kubectl@v3
        
      - name: Setup Helm
        uses: azure/setup-helm@v3
        
      - name: Check for outdated components
        run: |
          OUTDATED=$(echo '{
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
              "name": "get_outdated_components",
              "arguments": {}
            }
          }' | node dist/index-optimized.js | jq '.result.content[0].text | fromjson | .data')
          
          CRITICAL=$(echo "$OUTDATED" | jq '[.[] | select(.severity == "critical")] | length')
          
          if [ "$CRITICAL" -gt 0 ]; then
            echo "::error::Found $CRITICAL critical components that need updates"
            echo "$OUTDATED" | jq '[.[] | select(.severity == "critical")]'
            exit 1
          fi
```

### 2. Prometheus Metrics Export

```bash
#!/bin/bash
# metrics-exporter.sh

# Export metrics to Prometheus format
METRICS_FILE="/tmp/k8s_versions_metrics.prom"

# Get analysis data
ANALYSIS=$(echo '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "analyze_versions",
    "arguments": {}
  }
}' | node dist/index-optimized.js | jq '.result.content[0].text | fromjson | .data')

# Generate Prometheus metrics
cat > "$METRICS_FILE" << EOF
# HELP k8s_components_total Total number of components
# TYPE k8s_components_total gauge
k8s_components_total $(echo "$ANALYSIS" | jq '.summary.total')

# HELP k8s_components_outdated Number of outdated components
# TYPE k8s_components_outdated gauge
k8s_components_outdated $(echo "$ANALYSIS" | jq '.summary.outdated')

# HELP k8s_components_critical Number of critical components
# TYPE k8s_components_critical gauge
k8s_components_critical $(echo "$ANALYSIS" | jq '.summary.critical')

# HELP k8s_analysis_duration_seconds Time taken for analysis
# TYPE k8s_analysis_duration_seconds gauge
k8s_analysis_duration_seconds $(echo "$ANALYSIS" | jq '.performanceMetrics.analysisTime / 1000')
EOF

echo "Metrics exported to $METRICS_FILE"
```

### 3. Slack Notification

```bash
#!/bin/bash
# slack-notify.sh

SLACK_WEBHOOK_URL="$1"
NAMESPACE="${2:-production}"

if [ -z "$SLACK_WEBHOOK_URL" ]; then
  echo "Usage: $0 <slack-webhook-url> [namespace]"
  exit 1
fi

# Get outdated components
OUTDATED=$(echo '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "get_outdated_components",
    "arguments": {"namespace": "'${NAMESPACE}'"}
  }
}' | node dist/index-optimized.js | jq '.result.content[0].text | fromjson | .data')

CRITICAL_COUNT=$(echo "$OUTDATED" | jq '[.[] | select(.severity == "critical")] | length')
HIGH_COUNT=$(echo "$OUTDATED" | jq '[.[] | select(.severity == "high")] | length')
TOTAL_COUNT=$(echo "$OUTDATED" | jq 'length')

if [ "$TOTAL_COUNT" -gt 0 ]; then
  MESSAGE="🚨 *K8s Version Alert for $NAMESPACE*\\n"
  MESSAGE+="Critical: $CRITICAL_COUNT | High: $HIGH_COUNT | Total: $TOTAL_COUNT\\n"
  MESSAGE+="Please review and update outdated components."
  
  curl -X POST -H 'Content-type: application/json' \
    --data "{\"text\":\"$MESSAGE\"}" \
    "$SLACK_WEBHOOK_URL"
fi
```

## Performance Optimization Examples

### 1. Pre-warm Cache

```bash
#!/bin/bash
# prewarm-cache.sh

echo "🔥 Pre-warming cache..."

# Pre-load commonly accessed data
echo "Loading cluster info..."
echo '{"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": "get_cluster_info", "arguments": {}}}' | \
  node dist/index-optimized.js > /dev/null

echo "Loading pods..."
echo '{"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": "get_pods", "arguments": {}}}' | \
  node dist/index-optimized.js > /dev/null

echo "Loading Helm releases..."
echo '{"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": "get_helm_releases", "arguments": {}}}' | \
  node dist/index-optimized.js > /dev/null

echo "✅ Cache pre-warmed"
```

### 2. Batch Operations

```bash
#!/bin/bash
# batch-analysis.sh

NAMESPACES=("production" "staging" "development")

echo "🔄 Running batch analysis..."

for namespace in "${NAMESPACES[@]}"; do
  echo "Analyzing namespace: $namespace"
  
  # Run analysis in background for parallel processing
  (
    echo '{
      "jsonrpc": "2.0",
      "id": 1,
      "method": "tools/call",
      "params": {
        "name": "analyze_versions",
        "arguments": {"namespace": "'$namespace'"}
      }
    }' | node dist/index-optimized.js > "analysis-${namespace}.json"
  ) &
done

# Wait for all analyses to complete
wait

echo "✅ Batch analysis complete"
ls -la analysis-*.json
```

## Testing Examples

### Unit Test Example

```bash
#!/bin/bash
# test-specific-tool.sh

TOOL_NAME="$1"
ARGS="${2:-{}}"

if [ -z "$TOOL_NAME" ]; then
  echo "Usage: $0 <tool_name> [arguments_json]"
  exit 1
fi

echo "Testing tool: $TOOL_NAME"

START_TIME=$(date +%s%3N)

RESULT=$(echo '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "'$TOOL_NAME'",
    "arguments": '$ARGS'
  }
}' | node dist/index-optimized.js)

END_TIME=$(date +%s%3N)
DURATION=$((END_TIME - START_TIME))

echo "Duration: ${DURATION}ms"

# Check for errors
if echo "$RESULT" | jq -e '.error' > /dev/null; then
  echo "❌ Tool failed:"
  echo "$RESULT" | jq '.error'
  exit 1
else
  echo "✅ Tool succeeded"
  echo "$RESULT" | jq '.result.content[0].text | fromjson' 2>/dev/null || echo "$RESULT"
fi
```

These examples demonstrate the flexibility and power of the K8s Versions MCP Server for various use cases, from simple queries to complex automation workflows.