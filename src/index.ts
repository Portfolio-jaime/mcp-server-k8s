#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";
import { KubernetesService } from "./services/kubernetes.js";
import { HelmService } from "./services/helm.js";
import { VersionAnalyzer } from "./services/version-analyzer.js";

// Esquemas de validación
const GetPodsSchema = z.object({
  namespace: z.string().optional(),
  selector: z.string().optional(),
});

const GetHelmReleasesSchema = z.object({
  namespace: z.string().optional(),
  status: z.string().optional(),
});

const AnalyzeVersionsSchema = z.object({
  namespace: z.string().optional(),
  component: z.string().optional(),
});

const CompareVersionsSchema = z.object({
  component: z.string(),
  currentVersion: z.string(),
  targetVersion: z.string(),
});

class K8sVersionsMCPServer {
  private server: Server;
  private k8sService: KubernetesService;
  private helmService: HelmService;
  private versionAnalyzer: VersionAnalyzer;

  constructor() {
    this.server = new Server(
      {
        name: "k8s-versions-mcp",
        version: "1.0.0",
      }
    );

    this.k8sService = new KubernetesService();
    this.helmService = new HelmService();
    this.versionAnalyzer = new VersionAnalyzer();

    this.setupHandlers();
  }

  private setupHandlers() {
    // Listar herramientas disponibles
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: [
          {
            name: "get_pods",
            description: "Obtener información de pods en Kubernetes",
            inputSchema: {
              type: "object",
              properties: {
                namespace: {
                  type: "string",
                  description: "Namespace específico (opcional, por defecto todos)",
                },
                selector: {
                  type: "string",
                  description: "Selector de labels (opcional)",
                },
              },
            },
          },
          {
            name: "get_helm_releases",
            description: "Obtener información de releases de Helm",
            inputSchema: {
              type: "object",
              properties: {
                namespace: {
                  type: "string",
                  description: "Namespace específico (opcional)",
                },
                status: {
                  type: "string",
                  description: "Filtrar por status (deployed, failed, etc.)",
                },
              },
            },
          },
          {
            name: "get_cluster_info",
            description: "Obtener información general del cluster",
            inputSchema: {
              type: "object",
              properties: {},
            },
          },
          {
            name: "analyze_versions",
            description: "Analizar versiones de componentes en el cluster",
            inputSchema: {
              type: "object",
              properties: {
                namespace: {
                  type: "string",
                  description: "Namespace específico (opcional)",
                },
                component: {
                  type: "string",
                  description: "Componente específico a analizar (opcional)",
                },
              },
            },
          },
          {
            name: "compare_versions",
            description: "Comparar versiones de componentes",
            inputSchema: {
              type: "object",
              properties: {
                component: {
                  type: "string",
                  description: "Nombre del componente",
                },
                currentVersion: {
                  type: "string",
                  description: "Versión actual",
                },
                targetVersion: {
                  type: "string",
                  description: "Versión objetivo",
                },
              },
              required: ["component", "currentVersion", "targetVersion"],
            },
          },
          {
            name: "get_outdated_components",
            description: "Obtener componentes desactualizados",
            inputSchema: {
              type: "object",
              properties: {
                namespace: {
                  type: "string",
                  description: "Namespace específico (opcional)",
                },
              },
            },
          },
        ] as Tool[],
      };
    });

    // Manejar llamadas a herramientas
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case "get_pods":
            return await this.handleGetPods(args);
          case "get_helm_releases":
            return await this.handleGetHelmReleases(args);
          case "get_cluster_info":
            return await this.handleGetClusterInfo();
          case "analyze_versions":
            return await this.handleAnalyzeVersions(args);
          case "compare_versions":
            return await this.handleCompareVersions(args);
          case "get_outdated_components":
            return await this.handleGetOutdatedComponents(args);
          default:
            throw new Error(`Herramienta desconocida: ${name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: "text",
              text: `Error ejecutando ${name}: ${error instanceof Error ? error.message : String(error)}`,
            },
          ],
          isError: true,
        };
      }
    });
  }

  private async handleGetPods(args: unknown) {
    const { namespace, selector } = GetPodsSchema.parse(args);
    const pods = await this.k8sService.getPods(namespace, selector);
    
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(pods, null, 2),
        },
      ],
    };
  }

  private async handleGetHelmReleases(args: unknown) {
    const { namespace, status } = GetHelmReleasesSchema.parse(args);
    const releases = await this.helmService.getReleases(namespace, status);
    
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(releases, null, 2),
        },
      ],
    };
  }

  private async handleGetClusterInfo() {
    const clusterInfo = await this.k8sService.getClusterInfo();
    
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(clusterInfo, null, 2),
        },
      ],
    };
  }

  private async handleAnalyzeVersions(args: unknown) {
    const { namespace, component } = AnalyzeVersionsSchema.parse(args);
    const analysis = await this.versionAnalyzer.analyzeVersions(namespace, component);
    
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(analysis, null, 2),
        },
      ],
    };
  }

  private async handleCompareVersions(args: unknown) {
    const { component, currentVersion, targetVersion } = CompareVersionsSchema.parse(args);
    const comparison = await this.versionAnalyzer.compareVersions(
      component,
      currentVersion,
      targetVersion
    );
    
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(comparison, null, 2),
        },
      ],
    };
  }

  private async handleGetOutdatedComponents(args: unknown) {
    const { namespace } = z.object({ namespace: z.string().optional() }).parse(args);
    const outdated = await this.versionAnalyzer.getOutdatedComponents(namespace);
    
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(outdated, null, 2),
        },
      ],
    };
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error("🚀 K8s Versions MCP Server iniciado");
  }
}

// Iniciar el servidor
const server = new K8sVersionsMCPServer();
server.run().catch((error) => {
  console.error("💥 Error iniciando servidor:", error);
  process.exit(1);
});