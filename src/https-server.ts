#!/usr/bin/env node

/**
 * Servidor HTTPS para exponer MCP Server de Kubernetes
 * Con certificados self-signed para Claude Desktop
 */

import https from 'https';
import fs from 'fs';
import path from 'path';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

// Puerto del servidor
const PORT = process.env.PORT || 3002;
const CERT_DIR = path.join(process.cwd(), 'certs');

// Función para generar certificados self-signed
async function generateCertificates(): Promise<{ key: string; cert: string }> {
  console.log('🔐 Generando certificados SSL self-signed...');
  
  // Crear directorio de certificados
  if (!fs.existsSync(CERT_DIR)) {
    fs.mkdirSync(CERT_DIR, { recursive: true });
  }
  
  const keyPath = path.join(CERT_DIR, 'server.key');
  const certPath = path.join(CERT_DIR, 'server.crt');
  
  // Verificar si ya existen
  if (fs.existsSync(keyPath) && fs.existsSync(certPath)) {
    console.log('✅ Certificados existentes encontrados');
    return {
      key: fs.readFileSync(keyPath, 'utf8'),
      cert: fs.readFileSync(certPath, 'utf8')
    };
  }
  
  try {
    // Generar clave privada
    await execAsync(`openssl genrsa -out ${keyPath} 2048`);
    
    // Generar certificado self-signed
    const opensslCmd = `openssl req -new -x509 -key ${keyPath} -out ${certPath} -days 365 -subj "/C=US/ST=Dev/L=Local/O=MCP/OU=DevContainer/CN=localhost"`;
    await execAsync(opensslCmd);
    
    console.log('✅ Certificados generados exitosamente');
    
    return {
      key: fs.readFileSync(keyPath, 'utf8'),
      cert: fs.readFileSync(certPath, 'utf8')
    };
  } catch (error) {
    console.error('❌ Error generando certificados:', error);
    throw error;
  }
}

// Función para ejecutar comandos kubectl
async function runKubectl(command: string): Promise<string> {
  try {
    const { stdout } = await execAsync(`kubectl ${command}`);
    return stdout;
  } catch (error) {
    throw new Error(`Error ejecutando kubectl: ${error instanceof Error ? error.message : String(error)}`);
  }
}

// Función para ejecutar comandos helm
async function runHelm(command: string): Promise<string> {
  try {
    const { stdout } = await execAsync(`helm ${command}`);
    return stdout;
  } catch (error) {
    throw new Error(`Error ejecutando helm: ${error instanceof Error ? error.message : String(error)}`);
  }
}

// Herramientas disponibles
const tools = [
  {
    name: 'get_pods',
    description: 'Obtener información de pods en Kubernetes',
    inputSchema: {
      type: 'object',
      properties: {
        namespace: {
          type: 'string',
          description: 'Namespace específico (opcional)',
        },
      },
    },
  },
  {
    name: 'get_helm_releases',
    description: 'Obtener información de releases de Helm',
    inputSchema: {
      type: 'object',
      properties: {
        namespace: {
          type: 'string',
          description: 'Namespace específico (opcional)',
        },
      },
    },
  },
  {
    name: 'get_cluster_info',
    description: 'Obtener información general del cluster',
    inputSchema: {
      type: 'object',
      properties: {},
    },
  },
  {
    name: 'get_services',
    description: 'Obtener información de servicios',
    inputSchema: {
      type: 'object',
      properties: {
        namespace: {
          type: 'string',
          description: 'Namespace específico (opcional)',
        },
      },
    },
  },
  {
    name: 'get_namespaces',
    description: 'Obtener lista de namespaces',
    inputSchema: {
      type: 'object',
      properties: {},
    },
  },
];

// Función para procesar herramientas
async function processTool(name: string, args: any = {}) {
  try {
    switch (name) {
      case 'get_pods':
        const podsCmd = args.namespace ? `get pods -n ${args.namespace} -o json` : 'get pods --all-namespaces -o json';
        const podsOutput = await runKubectl(podsCmd);
        const podsData = JSON.parse(podsOutput);
        
        return {
          content: [{
            type: 'text',
            text: `📋 Pods encontrados: ${podsData.items?.length || 0}\n\n` +
                  podsData.items?.slice(0, 10).map((pod: any) => 
                    `• ${pod.metadata.name} (${pod.metadata.namespace}) - ${pod.status.phase}`
                  ).join('\n') || 'No se encontraron pods'
          }]
        };

      case 'get_helm_releases':
        const helmCmd = args.namespace ? `list -n ${args.namespace} -o json` : 'list --all-namespaces -o json';
        const helmOutput = await runHelm(helmCmd);
        const helmData = JSON.parse(helmOutput);
        
        return {
          content: [{
            type: 'text',
            text: `📦 Helm releases encontrados: ${helmData?.length || 0}\n\n` +
                  helmData?.map((release: any) => 
                    `• ${release.name} (${release.namespace}) - ${release.status} - v${release.revision}`
                  ).join('\n') || 'No se encontraron releases'
          }]
        };

      case 'get_cluster_info':
        const clusterInfo = await runKubectl('cluster-info');
        const version = await runKubectl('version --short');
        
        return {
          content: [{
            type: 'text',
            text: `🏁 Información del Cluster:\n\n${clusterInfo}\n\n📊 Versiones:\n${version}`
          }]
        };

      case 'get_services':
        const servicesCmd = args.namespace ? `get services -n ${args.namespace} -o json` : 'get services --all-namespaces -o json';
        const servicesOutput = await runKubectl(servicesCmd);
        const servicesData = JSON.parse(servicesOutput);
        
        return {
          content: [{
            type: 'text',
            text: `🌐 Servicios encontrados: ${servicesData.items?.length || 0}\n\n` +
                  servicesData.items?.slice(0, 10).map((svc: any) => 
                    `• ${svc.metadata.name} (${svc.metadata.namespace}) - ${svc.spec.type}`
                  ).join('\n') || 'No se encontraron servicios'
          }]
        };

      case 'get_namespaces':
        const nsOutput = await runKubectl('get namespaces -o json');
        const nsData = JSON.parse(nsOutput);
        
        return {
          content: [{
            type: 'text',
            text: `📁 Namespaces encontrados: ${nsData.items?.length || 0}\n\n` +
                  nsData.items?.map((ns: any) => 
                    `• ${ns.metadata.name} - ${ns.status.phase}`
                  ).join('\n') || 'No se encontraron namespaces'
          }]
        };

      default:
        throw new Error(`Herramienta desconocida: ${name}`);
    }
  } catch (error) {
    return {
      content: [{
        type: 'text',
        text: `❌ Error ejecutando ${name}: ${error instanceof Error ? error.message : String(error)}`
      }],
      isError: true
    };
  }
}

// Función principal para iniciar el servidor
async function startServer() {
  try {
    // Generar certificados
    const { key, cert } = await generateCertificates();
    
    // Crear servidor HTTPS
    const server = https.createServer({ key, cert }, async (req, res) => {
      // Headers CORS
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
      
      if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
      }
      
      // Health check
      if (req.method === 'GET' && req.url === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ 
          status: 'healthy', 
          server: 'k8s-versions-mcp-https',
          version: '1.0.0',
          protocol: 'HTTPS',
          timestamp: new Date().toISOString()
        }));
        return;
      }
      
      // Endpoint principal MCP
      if (req.method === 'POST' && req.url === '/mcp') {
        let body = '';
        
        req.on('data', (chunk) => {
          body += chunk.toString();
        });
        
        req.on('end', async () => {
          try {
            const jsonRequest = JSON.parse(body);
            let response;
            
            if (jsonRequest.method === 'tools/list') {
              response = {
                jsonrpc: '2.0',
                id: jsonRequest.id || 1,
                result: { tools }
              };
            } else if (jsonRequest.method === 'tools/call') {
              const toolResult = await processTool(
                jsonRequest.params.name, 
                jsonRequest.params.arguments
              );
              
              response = {
                jsonrpc: '2.0',
                id: jsonRequest.id || 1,
                result: toolResult
              };
            } else {
              response = {
                jsonrpc: '2.0',
                id: jsonRequest.id || 1,
                error: {
                  code: -32601,
                  message: 'Method not found'
                }
              };
            }
            
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify(response));
            
          } catch (error) {
            const errorResponse = {
              jsonrpc: '2.0',
              id: 1,
              error: {
                code: -32700,
                message: 'Parse error',
                data: error instanceof Error ? error.message : String(error)
              }
            };
            
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify(errorResponse));
          }
        });
        
        return;
      }
      
      // Página de información
      if (req.method === 'GET' && req.url === '/') {
        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end(`
<!DOCTYPE html>
<html>
<head>
    <title>K8s MCP HTTPS Server</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .endpoint { background: #f5f5f5; padding: 10px; margin: 10px 0; border-radius: 4px; }
        .url { background: #e8f4f8; padding: 15px; border-radius: 5px; font-size: 18px; font-weight: bold; }
        .warning { background: #fff3cd; padding: 10px; border-radius: 4px; border-left: 4px solid #ffc107; }
    </style>
</head>
<body>
    <h1>🔐 Kubernetes MCP HTTPS Server</h1>
    <p>Servidor HTTPS seguro para Claude Desktop</p>
    
    <h2>🌐 URL para Claude Desktop:</h2>
    <div class="url">https://localhost:${PORT}/mcp</div>
    
    <div class="warning">
        <strong>⚠️ Certificado Self-Signed:</strong><br>
        Tu navegador mostrará una advertencia de seguridad. Esto es normal para desarrollo local.
        En Chrome/Edge: Click "Advanced" → "Proceed to localhost (unsafe)"
    </div>
    
    <h2>🔧 Endpoints:</h2>
    <div class="endpoint">
        <strong>POST /mcp</strong> - Endpoint principal MCP
    </div>
    <div class="endpoint">
        <strong>GET /health</strong> - Health check
    </div>
    
    <h2>🛠️ Herramientas disponibles:</h2>
    <ul>
        <li><strong>get_pods</strong> - Lista pods del cluster</li>
        <li><strong>get_helm_releases</strong> - Lista releases de Helm</li>
        <li><strong>get_cluster_info</strong> - Información del cluster</li>
        <li><strong>get_services</strong> - Lista servicios</li>
        <li><strong>get_namespaces</strong> - Lista namespaces</li>
    </ul>
    
    <p><strong>Estado:</strong> ✅ Servidor HTTPS funcionando en puerto ${PORT}</p>
    <p><strong>Cluster:</strong> ${process.env.KUBECONFIG || 'default config'}</p>
    <p><strong>Certificados:</strong> ${CERT_DIR}</p>
</body>
</html>
        `);
        return;
      }
      
      // 404
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('Not Found');
    });

    server.listen(PORT, () => {
      console.log(`🔐 Kubernetes MCP HTTPS Server iniciado`);
      console.log(`📡 Puerto: ${PORT}`);
      console.log(`🔗 URL para Claude Desktop: https://localhost:${PORT}/mcp`);
      console.log(`📄 Información: https://localhost:${PORT}`);
      console.log(`❤️  Health: https://localhost:${PORT}/health`);
      console.log(`🔐 Certificados: ${CERT_DIR}`);
      console.log('');
      console.log('⚠️  IMPORTANTE: Tu navegador mostrará advertencia de certificado self-signed');
      console.log('   En Chrome: "Advanced" → "Proceed to localhost (unsafe)"');
    });

    process.on('uncaughtException', (error) => {
      console.error('❌ Error no capturado:', error);
    });

    process.on('unhandledRejection', (reason) => {
      console.error('❌ Promise rechazada:', reason);
    });

  } catch (error) {
    console.error('❌ Error iniciando servidor:', error);
    process.exit(1);
  }
}

// Iniciar servidor
startServer();