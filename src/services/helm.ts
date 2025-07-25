import { exec } from "child_process";
import { promisify } from "util";
import YAML from "yaml";

const execAsync = promisify(exec);

export interface HelmRelease {
  name: string;
  namespace: string;
  revision: number;
  updated: string;
  status: string;
  chart: string;
  appVersion: string;
  description?: string;
  values?: any;
  manifest?: string;
  notes?: string;
}

export interface HelmChart {
  name: string;
  version: string;
  appVersion: string;
  description: string;
  repository?: string;
}

export interface HelmRepository {
  name: string;
  url: string;
  status: string;
}

export class HelmService {
  async getReleases(namespace?: string, status?: string): Promise<HelmRelease[]> {
    try {
      let cmd = "helm list -o json";
      
      if (namespace) {
        cmd += ` -n ${namespace}`;
      } else {
        cmd += " --all-namespaces";
      }
      
      if (status) {
        cmd += ` --filter="${status}"`;
      }

      const { stdout } = await execAsync(cmd);
      const releases = JSON.parse(stdout);
      
      // Enriquecer con información adicional
      const enrichedReleases = await Promise.all(
        releases.map(async (release: any) => {
          try {
            const releaseInfo = await this.getReleaseDetails(release.name, release.namespace);
            return {
              name: release.name,
              namespace: release.namespace,
              revision: release.revision,
              updated: release.updated,
              status: release.status,
              chart: release.chart,
              appVersion: release.app_version,
              description: release.description,
              ...releaseInfo,
            };
          } catch (error) {
            console.error(`Error obteniendo detalles de ${release.name}:`, error);
            return {
              name: release.name,
              namespace: release.namespace,
              revision: release.revision,
              updated: release.updated,
              status: release.status,
              chart: release.chart,
              appVersion: release.app_version,
              description: release.description,
            };
          }
        })
      );

      return enrichedReleases;
    } catch (error) {
      throw new Error(`Error obteniendo releases de Helm: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  async getReleaseDetails(releaseName: string, namespace: string): Promise<Partial<HelmRelease>> {
    try {
      // Obtener valores del release
      const valuesCmd = `helm get values ${releaseName} -n ${namespace} -o json`;
      const { stdout: valuesOutput } = await execAsync(valuesCmd);
      const values = JSON.parse(valuesOutput);

      // Obtener manifest
      const manifestCmd = `helm get manifest ${releaseName} -n ${namespace}`;
      const { stdout: manifest } = await execAsync(manifestCmd);

      // Obtener notas
      let notes = "";
      try {
        const notesCmd = `helm get notes ${releaseName} -n ${namespace}`;
        const { stdout: notesOutput } = await execAsync(notesCmd);
        notes = notesOutput;
      } catch {
        // Las notas son opcionales
      }

      return {
        values,
        manifest,
        notes,
      };
    } catch (error) {
      console.error(`Error obteniendo detalles del release ${releaseName}:`, error);
      return {};
    }
  }

  async getRepositories(): Promise<HelmRepository[]> {
    try {
      const { stdout } = await execAsync("helm repo list -o json");
      const repos = JSON.parse(stdout);
      
      return repos.map((repo: any) => ({
        name: repo.name,
        url: repo.url,
        status: "active",
      }));
    } catch (error) {
      throw new Error(`Error obteniendo repositorios de Helm: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  async getChartVersions(chartName: string): Promise<any[]> {
    try {
      const { stdout } = await execAsync(`helm search repo ${chartName} --versions -o json`);
      return JSON.parse(stdout);
    } catch (error) {
      console.error(`Error obteniendo versiones del chart ${chartName}:`, error);
      return [];
    }
  }
}