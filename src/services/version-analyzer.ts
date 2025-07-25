import { KubernetesService, PodInfo } from "./kubernetes.js";
import { HelmService, HelmRelease } from "./helm.js";

export interface VersionAnalysis {
  namespace: string;
  components: ComponentVersion[];
  summary: {
    total: number;
    outdated: number;
    upToDate: number;
    unknown: number;
  };
  recommendations: string[];
}

export interface ComponentVersion {
  name: string;
  type: "pod" | "helm-release" | "container";
  currentVersion: string;
  latestVersion?: string;
  status: "up-to-date" | "outdated" | "unknown";
  namespace: string;
  images?: string[];
  chart?: string;
  severity?: "low" | "medium" | "high" | "critical";
  updateAvailable?: boolean;
  securityIssues?: string[];
}

export interface VersionComparison {
  component: string;
  currentVersion: string;
  targetVersion: string;
  comparison: "newer" | "older" | "same" | "invalid";
  recommendation: string;
  breakingChanges?: string[];
  migrationSteps?: string[];
}

export class VersionAnalyzer {
  private k8sService: KubernetesService;
  private helmService: HelmService;

  constructor() {
    this.k8sService = new KubernetesService();
    this.helmService = new HelmService();
  }

  async analyzeVersions(namespace?: string, component?: string): Promise<VersionAnalysis> {
    try {
      const components: ComponentVersion[] = [];
      
      // Analizar pods y sus imágenes
      const pods = await this.k8sService.getPods(namespace);
      const podComponents = this.analyzePods(pods, component);
      components.push(...podComponents);

      // Analizar releases de Helm
      const helmReleases = await this.helmService.getReleases(namespace);
      const helmComponents = await this.analyzeHelmReleases(helmReleases, component);
      components.push(...helmComponents);

      // Calcular estadísticas
      const summary = this.calculateSummary(components);
      
      // Generar recomendaciones
      const recommendations = this.generateRecommendations(components);

      return {
        namespace: namespace || "all",
        components,
        summary,
        recommendations,
      };
    } catch (error) {
      throw new Error(`Error analizando versiones: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private analyzePods(pods: PodInfo[], targetComponent?: string): ComponentVersion[] {
    const components: ComponentVersion[] = [];
    
    for (const pod of pods) {
      // Si se especifica un componente, filtrar
      if (targetComponent && !pod.name.includes(targetComponent)) {
        continue;
      }

      // Analizar cada imagen del pod
      for (const image of pod.images) {
        const imageInfo = this.parseImageVersion(image);
        
        components.push({
          name: `${pod.name}/${imageInfo.name}`,
          type: "container",
          currentVersion: imageInfo.version,
          status: "unknown", // Se determina después con verificaciones externas
          namespace: pod.namespace,
          images: [image],
        });
      }

      // Crear entrada para el pod completo
      components.push({
        name: pod.name,
        type: "pod",
        currentVersion: this.extractPodVersion(pod),
        status: "unknown",
        namespace: pod.namespace,
        images: pod.images,
      });
    }

    return components;
  }

  private async analyzeHelmReleases(releases: HelmRelease[], targetComponent?: string): Promise<ComponentVersion[]> {
    const components: ComponentVersion[] = [];

    for (const release of releases) {
      // Si se especifica un componente, filtrar
      if (targetComponent && !release.name.includes(targetComponent)) {
        continue;
      }

      try {
        // Obtener versiones disponibles del chart
        const chartName = release.chart.split('-')[0] || release.chart;
        const availableVersions = await this.helmService.getChartVersions(chartName);
        const latestVersion = availableVersions[0]?.version;
        const currentChartVersion = release.chart.split('-').slice(1).join('-');

        const status = this.compareHelmVersions(currentChartVersion, latestVersion);
        
        components.push({
          name: release.name,
          type: "helm-release",
          currentVersion: currentChartVersion,
          latestVersion,
          status,
          namespace: release.namespace,
          chart: release.chart,
          updateAvailable: status === "outdated",
          severity: this.calculateSeverity(currentChartVersion, latestVersion),
        });
      } catch (error) {
        console.error(`Error analizando release ${release.name}:`, error);
        
        components.push({
          name: release.name,
          type: "helm-release",
          currentVersion: release.chart,
          status: "unknown",
          namespace: release.namespace,
          chart: release.chart,
        });
      }
    }

    return components;
  }

  private parseImageVersion(image: string): { name: string; version: string } {
    const parts = image.split(':');
    if (parts.length < 2) {
      return { name: image, version: "latest" };
    }
    
    const version = parts[parts.length - 1] || "latest";
    const name = parts.slice(0, -1).join(':');
    
    return { name, version };
  }

  private extractPodVersion(pod: PodInfo): string {
    // Intentar extraer versión de labels comunes
    const versionLabels = ['version', 'app.kubernetes.io/version', 'chart-version'];
    
    for (const label of versionLabels) {
      if (pod.labels[label]) {
        return pod.labels[label];
      }
    }

    // Usar la versión de la primera imagen como fallback
    if (pod.images.length > 0) {
      return this.parseImageVersion(pod.images[0]!).version;
    }

    return "unknown";
  }

  private compareHelmVersions(current: string, latest?: string): "up-to-date" | "outdated" | "unknown" {
    if (!latest || !current) return "unknown";
    
    try {
      const currentParts = this.parseSemanticVersion(current);
      const latestParts = this.parseSemanticVersion(latest);
      
      if (this.compareVersionParts(currentParts, latestParts) < 0) {
        return "outdated";
      }
      
      return "up-to-date";
    } catch {
      return current === latest ? "up-to-date" : "unknown";
    }
  }

  private parseSemanticVersion(version: string): number[] {
    // Limpiar prefijos comunes
    const cleanVersion = version.replace(/^[vV]/, '').split('-')[0];
    return cleanVersion?.split('.').map(part => {
      const num = parseInt(part, 10);
      return isNaN(num) ? 0 : num;
    }) || [];
  }

  private compareVersionParts(version1: number[], version2: number[]): number {
    const maxLength = Math.max(version1.length, version2.length);
    
    for (let i = 0; i < maxLength; i++) {
      const v1 = version1[i] || 0;
      const v2 = version2[i] || 0;
      
      if (v1 < v2) return -1;
      if (v1 > v2) return 1;
    }
    
    return 0;
  }

  private calculateSeverity(current: string, latest?: string): "low" | "medium" | "high" | "critical" {
    if (!latest) return "low";
    
    try {
      const currentParts = this.parseSemanticVersion(current);
      const latestParts = this.parseSemanticVersion(latest);
      
      const majorDiff = (latestParts[0] || 0) - (currentParts[0] || 0);
      const minorDiff = (latestParts[1] || 0) - (currentParts[1] || 0);
      
      if (majorDiff > 2) return "critical";
      if (majorDiff > 1) return "high";
      if (majorDiff === 1 || minorDiff > 5) return "medium";
      
      return "low";
    } catch {
      return "low";
    }
  }

  private calculateSummary(components: ComponentVersion[]) {
    const total = components.length;
    const outdated = components.filter(c => c.status === "outdated").length;
    const upToDate = components.filter(c => c.status === "up-to-date").length;
    const unknown = components.filter(c => c.status === "unknown").length;

    return { total, outdated, upToDate, unknown };
  }

  private generateRecommendations(components: ComponentVersion[]): string[] {
    const recommendations: string[] = [];
    
    const outdatedComponents = components.filter(c => c.status === "outdated");
    const criticalComponents = components.filter(c => c.severity === "critical");
    const helmReleases = components.filter(c => c.type === "helm-release");
    
    if (criticalComponents.length > 0) {
      recommendations.push(
        `🚨 CRÍTICO: ${criticalComponents.length} componente(s) tienen versiones muy desactualizadas y requieren actualización inmediata`
      );
    }
    
    if (outdatedComponents.length > 0) {
      recommendations.push(
        `⚠️  ${outdatedComponents.length} componente(s) están desactualizados y deberían ser actualizados`
      );
    }
    
    if (helmReleases.some(r => r.status === "outdated")) {
      recommendations.push(
        "📈 Considera actualizar los releases de Helm usando 'helm upgrade' para obtener las últimas características y parches de seguridad"
      );
    }
    
    if (components.some(c => c.status === "unknown")) {
      recommendations.push(
        "🔍 Algunos componentes tienen versiones desconocidas. Considera añadir labels de versión para mejor seguimiento"
      );
    }

    return recommendations;
  }

  async compareVersions(component: string, currentVersion: string, targetVersion: string): Promise<VersionComparison> {
    try {
      const comparison = this.determineVersionRelation(currentVersion, targetVersion);
      const recommendation = this.generateUpdateRecommendation(comparison, currentVersion, targetVersion);
      
      return {
        component,
        currentVersion,
        targetVersion,
        comparison,
        recommendation,
        breakingChanges: await this.getBreakingChanges(component, currentVersion, targetVersion),
        migrationSteps: this.getMigrationSteps(component, comparison),
      };
    } catch (error) {
      throw new Error(`Error comparando versiones: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private determineVersionRelation(current: string, target: string): "newer" | "older" | "same" | "invalid" {
    try {
      const currentParts = this.parseSemanticVersion(current);
      const targetParts = this.parseSemanticVersion(target);
      
      const result = this.compareVersionParts(currentParts, targetParts);
      
      if (result === 0) return "same";
      if (result < 0) return "older";
      return "newer";
    } catch {
      return "invalid";
    }
  }

  private generateUpdateRecommendation(comparison: string, current: string, target: string): string {
    switch (comparison) {
      case "older":
        return `✅ Actualización recomendada de ${current} a ${target}`;
      case "newer":
        return `⚠️  La versión actual ${current} es más nueva que ${target}. Verifica la compatibilidad`;
      case "same":
        return `ℹ️  Las versiones son idénticas (${current})`;
      default:
        return `❌ No se puede comparar las versiones ${current} y ${target}`;
    }
  }

  private async getBreakingChanges(component: string, from: string, to: string): Promise<string[]> {
    // Esta función podría integrarse con APIs de documentación o changelog
    // Por ahora, retorna un placeholder basado en análisis de versión semántica
    
    try {
      const fromParts = this.parseSemanticVersion(from);
      const toParts = this.parseSemanticVersion(to);
      
      const majorDiff = (toParts[0] || 0) - (fromParts[0] || 0);
      
      if (majorDiff > 0) {
        return [
          `Cambio de versión mayor detectado (${from} → ${to})`,
          "Revisa la documentación de migración del componente",
          "Realiza pruebas exhaustivas antes de actualizar en producción",
        ];
      }
      
      return [];
    } catch {
      return ["No se pudieron determinar los cambios incompatibles"];
    }
  }

  private getMigrationSteps(component: string, comparison: string): string[] {
    const baseSteps = [
      "1. Realizar backup del estado actual",
      "2. Probar la actualización en un entorno de desarrollo",
      "3. Revisar logs y métricas post-actualización",
    ];

    if (comparison === "older") {
      return [
        ...baseSteps,
        "4. Programar ventana de mantenimiento si es necesario",
        "5. Ejecutar la actualización",
        "6. Verificar funcionalidad",
        "7. Monitorear por posibles problemas",
      ];
    }

    return baseSteps;
  }

  async getOutdatedComponents(namespace?: string): Promise<ComponentVersion[]> {
    const analysis = await this.analyzeVersions(namespace);
    return analysis.components.filter(c => c.status === "outdated");
  }
}