import { describe, it, expect, vi, beforeEach } from "vitest";
import { KubernetesService } from "../kubernetes-optimized.js";
import { CommandExecutor } from "../../utils/command-executor.js";

// Mock the CommandExecutor
vi.mock("../../utils/command-executor.js");

describe("KubernetesService", () => {
  let kubernetesService: KubernetesService;
  
  beforeEach(() => {
    kubernetesService = new KubernetesService();
    vi.clearAllMocks();
  });

  describe("getPods", () => {
    it("should fetch pods successfully", async () => {
      const mockPodList = {
        items: [
          {
            metadata: {
              name: "test-pod",
              namespace: "default",
              creationTimestamp: "2024-01-01T00:00:00Z",
              labels: { app: "test" },
              annotations: {},
            },
            spec: {
              nodeName: "test-node",
              containers: [{ image: "nginx:1.21.0" }],
            },
            status: {
              phase: "Running",
              containerStatuses: [{ ready: true, restartCount: 0 }],
            },
          },
        ],
      };

      vi.mocked(CommandExecutor.execute).mockResolvedValue({
        stdout: JSON.stringify(mockPodList),
        stderr: "",
        exitCode: 0,
      });

      const pods = await kubernetesService.getPods();

      expect(pods).toHaveLength(1);
      expect(pods[0].name).toBe("test-pod");
      expect(pods[0].namespace).toBe("default");
      expect(pods[0].status).toBe("Running");
      expect(pods[0].images).toEqual(["nginx:1.21.0"]);
    });

    it("should handle namespace filtering", async () => {
      vi.mocked(CommandExecutor.execute).mockResolvedValue({
        stdout: JSON.stringify({ items: [] }),
        stderr: "",
        exitCode: 0,
      });

      await kubernetesService.getPods("kube-system");

      expect(CommandExecutor.execute).toHaveBeenCalledWith(
        "kubectl get pods -o json -n kube-system",
        expect.any(Object)
      );
    });

    it("should handle selector filtering", async () => {
      vi.mocked(CommandExecutor.execute).mockResolvedValue({
        stdout: JSON.stringify({ items: [] }),
        stderr: "",
        exitCode: 0,
      });

      await kubernetesService.getPods(undefined, "app=nginx");

      expect(CommandExecutor.execute).toHaveBeenCalledWith(
        'kubectl get pods -o json --all-namespaces --selector="app=nginx"',
        expect.any(Object)
      );
    });

    it("should throw error on command failure", async () => {
      vi.mocked(CommandExecutor.execute).mockRejectedValue(
        new Error("kubectl command failed")
      );

      await expect(kubernetesService.getPods()).rejects.toThrow(
        "Error obteniendo pods"
      );
    });
  });

  describe("getClusterInfo", () => {
    it("should fetch cluster info successfully", async () => {
      const mockVersion = {
        serverVersion: { gitVersion: "v1.28.0" },
      };

      const mockNodes = {
        items: [
          {
            metadata: {
              name: "test-node",
              creationTimestamp: "2024-01-01T00:00:00Z",
              labels: { "node-role.kubernetes.io/control-plane": "" },
            },
            status: {
              conditions: [{ type: "Ready", status: "True" }],
              nodeInfo: {
                kubeletVersion: "v1.28.0",
                operatingSystem: "linux",
                osImage: "Ubuntu 22.04",
                kernelVersion: "5.15.0",
                containerRuntimeVersion: "containerd://1.6.0",
              },
              capacity: { cpu: "4", memory: "8Gi" },
              allocatable: { cpu: "3800m", memory: "7Gi" },
            },
          },
        ],
      };

      const mockNamespaces = {
        items: [
          { metadata: { name: "default" } },
          { metadata: { name: "kube-system" } },
        ],
      };

      vi.mocked(CommandExecutor.execute)
        .mockResolvedValueOnce({
          stdout: JSON.stringify(mockVersion),
          stderr: "",
          exitCode: 0,
        })
        .mockResolvedValueOnce({
          stdout: JSON.stringify(mockNodes),
          stderr: "",
          exitCode: 0,
        })
        .mockResolvedValueOnce({
          stdout: JSON.stringify(mockNamespaces),
          stderr: "",
          exitCode: 0,
        })
        .mockResolvedValueOnce({
          stdout: "5\n",
          stderr: "",
          exitCode: 0,
        })
        .mockResolvedValueOnce({
          stdout: "3\n",
          stderr: "",
          exitCode: 0,
        });

      const clusterInfo = await kubernetesService.getClusterInfo();

      expect(clusterInfo.version).toBe("v1.28.0");
      expect(clusterInfo.nodes).toHaveLength(1);
      expect(clusterInfo.nodes[0].name).toBe("test-node");
      expect(clusterInfo.nodes[0].roles).toEqual(["control-plane"]);
      expect(clusterInfo.namespaces).toEqual(["default", "kube-system"]);
      expect(clusterInfo.totalPods).toBe(5);
      expect(clusterInfo.totalServices).toBe(3);
    });
  });

  describe("getServices", () => {
    it("should fetch services successfully", async () => {
      const mockServices = {
        items: [
          {
            metadata: {
              name: "test-service",
              namespace: "default",
              creationTimestamp: "2024-01-01T00:00:00Z",
            },
            spec: {
              type: "ClusterIP",
              clusterIP: "10.0.0.1",
              ports: [{ port: 80, targetPort: 8080, protocol: "TCP" }],
              selector: { app: "test" },
            },
            status: {},
          },
        ],
      };

      vi.mocked(CommandExecutor.execute).mockResolvedValue({
        stdout: JSON.stringify(mockServices),
        stderr: "",
        exitCode: 0,
      });

      const services = await kubernetesService.getServices();

      expect(services).toHaveLength(1);
      expect(services[0].name).toBe("test-service");
      expect(services[0].type).toBe("ClusterIP");
      expect(services[0].clusterIP).toBe("10.0.0.1");
      expect(services[0].ports).toHaveLength(1);
    });
  });

  describe("cache functionality", () => {
    it("should use cache for repeated requests", async () => {
      const mockPodList = { items: [] };
      
      vi.mocked(CommandExecutor.execute).mockResolvedValue({
        stdout: JSON.stringify(mockPodList),
        stderr: "",
        exitCode: 0,
      });

      // First call
      await kubernetesService.getPods();
      
      // Second call should use cache
      await kubernetesService.getPods();

      // Should only call kubectl once due to caching
      expect(CommandExecutor.execute).toHaveBeenCalledTimes(1);
    });

    it("should clear cache", () => {
      kubernetesService.clearCache();
      const stats = kubernetesService.getCacheStats();
      expect(stats.size).toBe(0);
    });
  });
});