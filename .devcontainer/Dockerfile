# Dockerfile corregido para el entorno de desarrollo K8s MCP
FROM mcr.microsoft.com/devcontainers/javascript-node:1-18-bullseye

# Metadatos
LABEL maintainer="DevOps Team"
LABEL description="Development environment for K8s Versions MCP Server"
LABEL version="1.0.0"

# Argumentos de construcción
ARG KUBECTL_VERSION=v1.28.4
ARG HELM_VERSION=v3.13.2
ARG MINIKUBE_VERSION=v1.32.0

# Variables de entorno
ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_ENV=development
ENV KUBECONFIG=/home/node/.kube/config

# Cambiar al usuario root para instalaciones
USER root

# Actualizar sistema e instalar dependencias base (SIN yq)
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    git \
    vim \
    nano \
    htop \
    jq \
    unzip \
    bash-completion \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Instalar yq manualmente desde GitHub releases
RUN YQ_VERSION="v4.40.5" && \
    YQ_BINARY="yq_linux_$(dpkg --print-architecture)" && \
    wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${YQ_BINARY}" && \
    chmod +x /usr/local/bin/yq

# Instalar Docker CLI
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Instalar kubectl
RUN curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/$(dpkg --print-architecture)/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

# Instalar Helm
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    && chmod 700 get_helm.sh \
    && HELM_INSTALL_DIR=/usr/local/bin ./get_helm.sh --version ${HELM_VERSION} \
    && rm get_helm.sh

# Instalar Minikube
RUN curl -Lo minikube https://storage.googleapis.com/minikube/releases/${MINIKUBE_VERSION}/minikube-linux-$(dpkg --print-architecture) \
    && install minikube /usr/local/bin/ \
    && rm minikube

# Instalar herramientas adicionales de Kubernetes
RUN curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-$(dpkg --print-architecture) \
    && install kind /usr/local/bin/kind \
    && rm kind

# Instalar k9s (CLI dashboard para Kubernetes)
RUN K9S_VERSION="v0.28.2" && \
    K9S_ARCH=$(dpkg --print-architecture) && \
    if [ "$K9S_ARCH" = "amd64" ]; then K9S_ARCH="x86_64"; fi && \
    if [ "$K9S_ARCH" = "arm64" ]; then K9S_ARCH="arm64"; fi && \
    curl -sL "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${K9S_ARCH}.tar.gz" | tar -xz -C /tmp && \
    mv /tmp/k9s /usr/local/bin/

# Instalar kubectx y kubens
RUN git clone https://github.com/ahmetb/kubectx /opt/kubectx \
    && ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx \
    && ln -s /opt/kubectx/kubens /usr/local/bin/kubens

# Cambiar al usuario node
USER node

# Crear directorios necesarios
RUN mkdir -p /home/node/.kube \
    && mkdir -p /home/node/.minikube \
    && mkdir -p /home/node/.config/helm

# Configurar bash completion para kubectl y helm
RUN echo 'source <(kubectl completion bash)' >> /home/node/.bashrc \
    && echo 'source <(helm completion bash)' >> /home/node/.bashrc \
    && echo 'alias k=kubectl' >> /home/node/.bashrc \
    && echo 'complete -F __start_kubectl k' >> /home/node/.bashrc

# Configurar aliases útiles
RUN echo 'alias ll="ls -la"' >> /home/node/.bashrc \
    && echo 'alias k="kubectl"' >> /home/node/.bashrc \
    && echo 'alias kgp="kubectl get pods"' >> /home/node/.bashrc \
    && echo 'alias kgs="kubectl get services"' >> /home/node/.bashrc \
    && echo 'alias kgn="kubectl get nodes"' >> /home/node/.bashrc \
    && echo 'alias h="helm"' >> /home/node/.bashrc \
    && echo 'alias hls="helm list --all-namespaces"' >> /home/node/.bashrc

# Configurar PS1 personalizado con contexto de Kubernetes
RUN echo 'export PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\] \[\033[01;35m\][\$(kubectl config current-context 2>/dev/null || echo \"no-context\")]\[\033[00m\]\$ "' >> /home/node/.bashrc

# Configurar Git (valores por defecto)
RUN git config --global init.defaultBranch main \
    && git config --global pull.rebase false

# Instalar extensiones globales de npm útiles para desarrollo
RUN npm install -g \
    typescript \
    ts-node \
    nodemon \
    @types/node \
    eslint \
    prettier

# Crear directorio de trabajo
WORKDIR /workspace

# Exponer puertos comunes
EXPOSE 3000 8080 8081 9090 3001

# Comando por defecto
CMD ["bash"]

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD kubectl version --client || exit 1