#!/usr/bin/env node

/**
 * Kubernetes MCP Server con proxy para devcontainer
 * Ejecuta kubectl y helm dentro del devcontainer desde el host
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { exec } from 'child_process';
import { promisify } from 'util';
import path from 'path';

const execAsync = promisify(exec);

// Rutas a los scripts proxy
const SCRIPT_DIR = path.join(process.cwd(), 'scripts');
const KUBECTL_PROXY = path.join(SCRIPT_DIR, 'kubectl-proxy.sh');
const HELM_PROXY = path.join(SCRIPT_DIR, 'helm-proxy.sh');

// Función para ejecutar comandos kubectl via proxy
async function runKubectl(command: string): Promise<string> {
  try {
    console.error(`🔧 Ejecutando: kubectl ${command}`);
    const { stdout, stderr } = await execAsync(`bash "${KUBECTL_PROXY}" ${command}`, { timeout: 30000 });
    
    if (stderr && !stdout) {
      console.error(`⚠️  kubectl stderr: ${stderr}`);
      throw new Error(`kubectl error: ${stderr}`);
    }
    
    console.error(`✅ kubectl completado exitosamente`);
    return stdout;
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    console.error(`❌ Error kubectl: ${errorMsg}`);
    throw new Error(`Error ejecutando kubectl: ${errorMsg}`);
  }
}

// Función para ejecutar comandos helm via proxy
async function runHelm(command: string): Promise<string> {
  try {
    console.error(`🔧 Ejecutando: helm ${command}`);
    const { stdout, stderr } = await execAsync(`bash "${HELM_PROXY}" ${command}`, { timeout: 30000 });
    
    if (stderr && !stdout) {
      console.error(`⚠️  helm stderr: ${stderr}`);
      throw new Error(`helm error: ${stderr}`);
    }
    
    console.error(`✅ helm completado exitosamente`);
    return stdout;
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    console.error(`❌ Error helm: ${errorMsg}`);
    throw new Error(`Error ejecutando helm: ${errorMsg}`);
  }
}

// Crear servidor MCP
const server = new Server(
  {
    name: 'k8s-versions-mcp-proxy',
    version: '1.0.0',
  }
);

// Registrar herramientas
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
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
        name: 'get_namespaces',
        description: 'Obtener lista de namespaces',
        inputSchema: {
          type: 'object',
          properties: {},
        },
      },
    ],
  };
});

// Registrar manejador de herramientas
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'get_pods':
        const podsCmd = args?.namespace ? `get pods -n ${args.namespace} -o json` : 'get pods --all-namespaces -o json';
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

      case 'get_services':
        const servicesCmd = args?.namespace ? `get services -n ${args.namespace} -o json` : 'get services --all-namespaces -o json';
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

      case 'get_helm_releases':
        const helmCmd = args?.namespace ? `list -n ${args.namespace} -o json` : 'list --all-namespaces -o json';
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
        const version = await runKubectl('version');
        
        return {
          content: [{
            type: 'text',
            text: `🏁 Información del Cluster:\n\n${clusterInfo}\n\n📊 Versiones:\n${version}`
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
      content: [
        {
          type: 'text',
          text: `❌ Error ejecutando ${name}: ${error instanceof Error ? error.message : String(error)}`,
        },
      ],
      isError: true,
    };
  }
});

// Iniciar servidor
async function main() {
  try {
    const transport = new StdioServerTransport();
    
    // Manejo de errores de transporte
    transport.onclose = () => {
      console.error('📡 Transport closed');
      process.exit(0);
    };
    
    transport.onerror = (error: any) => {
      console.error('❌ Transport error:', error);
      process.exit(1);
    };
    
    await server.connect(transport);
    console.error('🚀 K8s Versions MCP Server (Proxy) iniciado');
    
    // Manejo de señales del sistema
    process.on('SIGINT', () => {
      console.error('📴 Received SIGINT, shutting down gracefully');
      process.exit(0);
    });
    
    process.on('SIGTERM', () => {
      console.error('📴 Received SIGTERM, shutting down gracefully');
      process.exit(0);
    });
    
    // Manejo de errores no capturados
    process.on('uncaughtException', (error) => {
      console.error('💥 Uncaught exception:', error);
      process.exit(1);
    });
    
    process.on('unhandledRejection', (reason) => {
      console.error('💥 Unhandled rejection:', reason);
      process.exit(1);
    });
    
  } catch (error) {
    console.error('💥 Failed to start server:', error);
    process.exit(1);
  }
}

main().catch((error) => {
  console.error('💥 Fatal error:', error);
  process.exit(1);
});