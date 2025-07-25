import { exec } from "child_process";
import { promisify } from "util";
import YAML from "yaml";

const execAsync = promisify(exec);

export interface PodInfo {
  name: string;
  namespace: string;
  status: string;
  ready: string;
  restarts: number;
  age: string;
  node: string;
  images: string[];
  labels: Record<string, string>;
  annotations: Record<string, string>;
}

export interface ClusterInfo {
  version: string;
  nodes: NodeInfo[];
  namespaces: string[];
  totalPods: number;
  totalServices: number;
}

export interface NodeInfo {
  name: string;
  status: string;
  roles: string[];
  age: string;
  version: string;
  os: string;
  kernel: string;
  containerRuntime: string;
}

export class KubernetesService {
  async getPods(namespace?: string, selector?: string): Promise<PodInfo[]> {
    try {
      let cmd = "kubectl get pods -o json";
      
      if (namespace) {
        cmd += ` -n ${namespace}`;
      } else {
        cmd += " --all-namespaces";
      }
      
      if (selector) {
        cmd += ` --selector="${selector}"`;
      }

      const { stdout } = await execAsync(cmd);
      const result = JSON.parse(stdout);
      
      const pods: PodInfo[] = result.items.map((pod: any) => ({
        name: pod.metadata.name,
        namespace: pod.metadata.namespace,
        status: pod.status.phase,
        ready: this.calculateReadyStatus(pod),
        restarts: this.calculateRestarts(pod),
        age: this.calculateAge(pod.metadata.creationTimestamp),
        node: pod.spec.nodeName || "Unknown",
        images: this.extractImages(pod),
        labels: pod.metadata.labels || {},
        annotations: pod.metadata.annotations || {},
      }));

      return pods;
    } catch (error) {
      throw new Error(`Error obteniendo pods: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  async getClusterInfo(): Promise<ClusterInfo> {
    try {
      // Obtener versión del cluster
      const { stdout: versionOutput } = await execAsync("kubectl version --client=false -o json");
      const versionData = JSON.parse(versionOutput);
      
      // Obtener información de nodos
      const { stdout: nodesOutput } = await execAsync("kubectl get nodes -o json");
      const nodesData = JSON.parse(nodesOutput);
      
      // Obtener namespaces
      const { stdout: nsOutput } = await execAsync("kubectl get namespaces -o json");
      const nsData = JSON.parse(nsOutput);
      
      // Obtener conteo de pods y servicios
      const { stdout: podsCount } = await execAsync("kubectl get pods --all-namespaces --no-headers | wc -l");
      const { stdout: servicesCount } = await execAsync("kubectl get services --all-namespaces --no-headers | wc -l");

      const nodes: NodeInfo[] = nodesData.items.map((node: any) => ({
        name: node.metadata.name,
        status: this.getNodeStatus(node),
        roles: this.getNodeRoles(node),
        age: this.calculateAge(node.metadata.creationTimestamp),
        version: node.status.nodeInfo.kubeletVersion,
        os: `${node.status.nodeInfo.operatingSystem} ${node.status.nodeInfo.osImage}`,
        kernel: node.status.nodeInfo.kernelVersion,
        containerRuntime: node.status.nodeInfo.containerRuntimeVersion,
      }));

      return {
        version: versionData.serverVersion.gitVersion,
        nodes,
        namespaces: nsData.items.map((ns: any) => ns.metadata.name),
        totalPods: parseInt(podsCount.trim()),
        totalServices: parseInt(servicesCount.trim()),
      };
    } catch (error) {
      throw new Error(`Error obteniendo información del cluster: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  async getServices(namespace?: string): Promise<any[]> {
    try {
      let cmd = "kubectl get services -o json";
      
      if (namespace) {
        cmd += ` -n ${namespace}`;
      } else {
        cmd += " --all-namespaces";
      }

      const { stdout } = await execAsync(cmd);
      const result = JSON.parse(stdout);
      
      return result.items.map((service: any) => ({
        name: service.metadata.name,
        namespace: service.metadata.namespace,
        type: service.spec.type,
        clusterIP: service.spec.clusterIP,
        externalIP: service.status.loadBalancer?.ingress?.[0]?.ip || "None",
        ports: service.spec.ports || [],
        age: this.calculateAge(service.metadata.creationTimestamp),
        selector: service.spec.selector || {},
      }));
    } catch (error) {
      throw new Error(`Error obteniendo servicios: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  async getConfigMaps(namespace?: string): Promise<any[]> {
    try {
      let cmd = "kubectl get configmaps -o json";
      
      if (namespace) {
        cmd += ` -n ${namespace}`;
      } else {
        cmd += " --all-namespaces";
      }

      const { stdout } = await execAsync(cmd);
      const result = JSON.parse(stdout);
      
      return result.items.map((cm: any) => ({
        name: cm.metadata.name,
        namespace: cm.metadata.namespace,
        dataKeys: Object.keys(cm.data || {}),
        age: this.calculateAge(cm.metadata.creationTimestamp),
      }));
    } catch (error) {
      throw new Error(`Error obteniendo ConfigMaps: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private calculateReadyStatus(pod: any): string {
    if (!pod.status.containerStatuses) return "0/0";
    
    const total = pod.status.containerStatuses.length;
    const ready = pod.status.containerStatuses.filter((c: any) => c.ready).length;
    
    return `${ready}/${total}`;
  }

  private calculateRestarts(pod: any): number {
    if (!pod.status.containerStatuses) return 0;
    
    return pod.status.containerStatuses.reduce(
      (total: number, container: any) => total + (container.restartCount || 0),
      0
    );
  }

  private calculateAge(timestamp: string): string {
    const now = new Date();
    const created = new Date(timestamp);
    const diffMs = now.getTime() - created.getTime();
    
    const days = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    const hours = Math.floor((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
    
    if (days > 0) return `${days}d`;
    if (hours > 0) return `${hours}h`;
    return `${minutes}m`;
  }

  private extractImages(pod: any): string[] {
    const images = new Set<string>();
    
    // Imágenes de containers
    if (pod.spec.containers) {
      pod.spec.containers.forEach((container: any) => {
        if (container.image) images.add(container.image);
      });
    }
    
    // Imágenes de init containers
    if (pod.spec.initContainers) {
      pod.spec.initContainers.forEach((container: any) => {
        if (container.image) images.add(container.image);
      });
    }
    
    return Array.from(images);
  }

  private getNodeStatus(node: any): string {
    const conditions = node.status.conditions || [];
    const readyCondition = conditions.find((c: any) => c.type === "Ready");
    return readyCondition?.status === "True" ? "Ready" : "NotReady";
  }

  private getNodeRoles(node: any): string[] {
    const labels = node.metadata.labels || {};
    const roles: string[] = [];
    
    Object.keys(labels).forEach(label => {
      if (label.startsWith("node-role.kubernetes.io/")) {
        const role = label.replace("node-role.kubernetes.io/", "");
        if (role) roles.push(role);
      }
    });
    
    return roles.length > 0 ? roles : ["worker"];
  }
}