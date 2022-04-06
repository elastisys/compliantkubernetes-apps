FROM ubuntu:20.04

RUN  apt-get update && \
     apt-get install -y software-properties-common && \
     add-apt-repository ppa:git-core/ppa && \
     apt-get update && \
     apt-get install -y \
         python3-pip make git wget \
         unzip ssh gettext-base \
         jq pwgen curl apache2-utils \
         net-tools iputils-ping && \
     rm -rf /var/lib/apt/lists/*

# Kubectl
ENV KUBECTL_VERSION "v1.22.6"
RUN wget "https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl

# sops
# NOTE: This needs to be installed before the helm-secrets plugin.
ENV SOPS_VERSION="3.6.1"
RUN wget https://github.com/mozilla/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux && \
    mv ./sops-v${SOPS_VERSION}.linux /usr/local/bin/sops && \
    chmod +x /usr/local/bin/sops

# Helm
ENV HELM_VERSION "v3.8.0"
RUN wget "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" && \
    tar -zxvf "helm-${HELM_VERSION}-linux-amd64.tar.gz" && \
    mv linux-amd64/helm /usr/local/bin/helm && \
    rm -rf linux-amd64/ "helm-${HELM_VERSION}-linux-amd64.tar.gz"
# We need to use this variable to override the default data path for helm
# TODO Change when this is closed https://github.com/helm/helm/issues/7919
# Should come with v3.3.0, see https://github.com/helm/helm/pull/7983
ENV XDG_DATA_HOME=/root/.config
RUN helm plugin install https://github.com/databus23/helm-diff --version v3.1.2
RUN helm plugin install https://github.com/jkroepke/helm-secrets --version v3.12.0

# Helmfile
ENV HELMFILE_VERSION "v0.144.0"
RUN wget "https://github.com/roboll/helmfile/releases/download/${HELMFILE_VERSION}/helmfile_linux_amd64" && \
    chmod +x helmfile_linux_amd64 && \
    mv helmfile_linux_amd64 /usr/local/bin/helmfile

# s3cmd
ENV S3CMD_VERSION "2.0.2"
RUN wget "https://github.com/s3tools/s3cmd/releases/download/v${S3CMD_VERSION}/s3cmd-${S3CMD_VERSION}.tar.gz" && \
    tar -zxvf "s3cmd-${S3CMD_VERSION}.tar.gz" && \
    pip3 install setuptools==45.2.0 && \
    cd "s3cmd-${S3CMD_VERSION}" && \
    python3 setup.py install && \
    cd ../ && \
    rm "s3cmd-${S3CMD_VERSION}.tar.gz"

# yq
ENV YQ_VERSION "3.4.1"
RUN wget "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" && \
    chmod +x yq_linux_amd64 && \
    mv yq_linux_amd64 /usr/local/bin/yq

# opa
ENV OPA_VERSION "v0.17.2"
RUN wget "https://github.com/open-policy-agent/opa/releases/download/${OPA_VERSION}/opa_linux_amd64" && \
    chmod +x opa_linux_amd64 && \
    mv opa_linux_amd64 /usr/local/bin/opa

# Bats
ENV BATS_VERSION "1.3.0"
RUN wget https://github.com/bats-core/bats-core/archive/refs/tags/v${BATS_VERSION}.tar.gz && \
    tar -zxvf "v${BATS_VERSION}.tar.gz" && \
    cd ./bats-core-${BATS_VERSION} && \
    ./install.sh /usr/local
