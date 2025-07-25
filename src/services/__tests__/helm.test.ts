import { describe, it, expect, vi, beforeEach } from "vitest";
import { HelmService } from "../helm-optimized.js";
import { CommandExecutor } from "../../utils/command-executor.js";

vi.mock("../../utils/command-executor.js");

describe("HelmService", () => {
  let helmService: HelmService;
  
  beforeEach(() => {
    helmService = new HelmService();
    vi.clearAllMocks();
  });

  describe("getReleases", () => {
    it("should fetch Helm releases successfully", async () => {
      const mockReleases = [
        {
          name: "test-release",
          namespace: "default",
          revision: 1,
          updated: "2024-01-01 00:00:00",
          status: "deployed",
          chart: "nginx-1.21.0",
          app_version: "1.21.0",
          description: "Test release",
        },
      ];

      vi.mocked(CommandExecutor.execute).mockResolvedValue({
        stdout: JSON.stringify(mockReleases),
        stderr: "",
        exitCode: 0,
      });

      const releases = await helmService.getReleases();

      expect(releases).toHaveLength(1);
      expect(releases[0].name).toBe("test-release");
      expect(releases[0].status).toBe("deployed");
      expect(releases[0].chart).toBe("nginx-1.21.0");
    });

    it("should handle namespace filtering", async () => {
      vi.mocked(CommandExecutor.execute).mockResolvedValue({
        stdout: JSON.stringify([]),
        stderr: "",
        exitCode: 0,
      });

      await helmService.getReleases("production");

      expect(CommandExecutor.execute).toHaveBeenCalledWith(
        "helm list -o json -n production",
        expect.any(Object)
      );
    });

    it("should handle status filtering", async () => {
      vi.mocked(CommandExecutor.execute).mockResolvedValue({
        stdout: JSON.stringify([]),
        stderr: "",
        exitCode: 0,
      });

      await helmService.getReleases(undefined, "failed");

      expect(CommandExecutor.execute).toHaveBeenCalledWith(
        'helm list -o json --all-namespaces --filter="failed"',
        expect.any(Object)
      );
    });
  });

  describe("getReleaseDetails", () => {
    it("should fetch release details successfully", async () => {
      const mockValues = { key: "value" };
      const mockManifest = "apiVersion: v1\nkind: Pod";
      const mockNotes = "Thank you for installing!";
      const mockHistory = [
        {
          revision: 1,
          updated: "2024-01-01 00:00:00",
          status: "deployed",
          chart: "nginx-1.21.0",
          app_version: "1.21.0",
          description: "Install complete",
        },
      ];

      vi.mocked(CommandExecutor.execute)
        .mockResolvedValueOnce({
          stdout: JSON.stringify(mockValues),
          stderr: "",
          exitCode: 0,
        })
        .mockResolvedValueOnce({
          stdout: mockManifest,
          stderr: "",
          exitCode: 0,
        })
        .mockResolvedValueOnce({
          stdout: mockNotes,
          stderr: "",
          exitCode: 0,
        })
        .mockResolvedValueOnce({
          stdout: JSON.stringify(mockHistory),
          stderr: "",
          exitCode: 0,
        });

      const details = await helmService.getReleaseDetails("test-release", "default");

      expect(details.values).toEqual(mockValues);
      expect(details.manifest).toBe(mockManifest);
      expect(details.notes).toBe(mockNotes);
      expect(details.history).toHaveLength(1);
    });

    it("should handle partial failures gracefully", async () => {
      // Mock values command success, but others fail
      vi.mocked(CommandExecutor.execute)
        .mockResolvedValueOnce({
          stdout: JSON.stringify({ key: "value" }),
          stderr: "",
          exitCode: 0,
        })
        .mockRejectedValueOnce(new Error("Manifest command failed"))
        .mockRejectedValueOnce(new Error("Notes command failed"))
        .mockRejectedValueOnce(new Error("History command failed"));

      const details = await helmService.getReleaseDetails("test-release", "default");

      expect(details.values).toEqual({ key: "value" });
      expect(details.manifest).toBeUndefined();
      expect(details.notes).toBeUndefined();
      expect(details.history).toBeUndefined();
    });
  });

  describe("getRepositories", () => {
    it("should fetch repositories successfully", async () => {
      const mockRepos = [
        {
          name: "bitnami",
          url: "https://charts.bitnami.com/bitnami",
        },
        {
          name: "stable",
          url: "https://charts.helm.sh/stable",
        },
      ];

      vi.mocked(CommandExecutor.execute).mockResolvedValue({
        stdout: JSON.stringify(mockRepos),
        stderr: "",
        exitCode: 0,
      });

      const repositories = await helmService.getRepositories();

      expect(repositories).toHaveLength(2);
      expect(repositories[0].name).toBe("bitnami");
      expect(repositories[0].url).toBe("https://charts.bitnami.com/bitnami");
      expect(repositories[0].status).toBe("active");
    });

    it("should handle no repositories configured", async () => {
      vi.mocked(CommandExecutor.execute).mockRejectedValue({
        stderr: "no repositories",
        message: "Command failed",
      });

      const repositories = await helmService.getRepositories();

      expect(repositories).toHaveLength(0);
    });
  });

  describe("getChartVersions", () => {
    it("should fetch chart versions successfully", async () => {
      const mockVersions = [
        {
          name: "bitnami/nginx",
          version: "15.5.1",
          app_version: "1.25.3",
          description: "NGINX web server",
          deprecated: false,
        },
        {
          name: "bitnami/nginx",
          version: "15.4.4",
          app_version: "1.24.0",
          description: "NGINX web server",
          deprecated: false,
        },
      ];

      vi.mocked(CommandExecutor.execute).mockResolvedValue({
        stdout: JSON.stringify(mockVersions),
        stderr: "",
        exitCode: 0,
      });

      const versions = await helmService.getChartVersions("nginx", "bitnami");

      expect(versions).toHaveLength(2);
      expect(versions[0].version).toBe("15.5.1");
      expect(versions[0].appVersion).toBe("1.25.3");
      expect(versions[1].version).toBe("15.4.4");
    });
  });

  describe("updateRepositories", () => {
    it("should update repositories successfully", async () => {
      vi.mocked(CommandExecutor.execute).mockResolvedValue({
        stdout: "Successfully updated repositories",
        stderr: "",
        exitCode: 0,
      });

      await expect(helmService.updateRepositories()).resolves.not.toThrow();

      expect(CommandExecutor.execute).toHaveBeenCalledWith(
        "helm repo update",
        expect.any(Object)
      );
    });
  });

  describe("getReleaseStatus", () => {
    it("should get release status successfully", async () => {
      const mockStatus = {
        info: {
          status: "deployed",
          last_deployed: "2024-01-01T00:00:00Z",
        },
        version: 1,
      };

      vi.mocked(CommandExecutor.execute).mockResolvedValue({
        stdout: JSON.stringify(mockStatus),
        stderr: "",
        exitCode: 0,
      });

      const status = await helmService.getReleaseStatus("test-release", "default");

      expect(status.status).toBe("deployed");
      expect(status.lastDeployed).toBe("2024-01-01T00:00:00Z");
      expect(status.revision).toBe(1);
    });
  });

  describe("cache functionality", () => {
    it("should cache release data", async () => {
      vi.mocked(CommandExecutor.execute).mockResolvedValue({
        stdout: JSON.stringify([]),
        stderr: "",
        exitCode: 0,
      });

      // First call
      await helmService.getReleases();
      // Second call should use cache
      await helmService.getReleases();

      expect(CommandExecutor.execute).toHaveBeenCalledTimes(1);
    });

    it("should provide cache stats", () => {
      const stats = helmService.getCacheStats();
      expect(stats).toHaveProperty("size");
      expect(typeof stats.size).toBe("number");
    });
  });
});