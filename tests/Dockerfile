FROM ubuntu:rolling
LABEL org.opencontainers.image.source https://github.com/elastisys/compliantkubernetes-apps

ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=Etc/UTC

RUN apt-get update && \
    apt-get install -y apache2-utils bats curl dnsutils gettext-base git gpg iputils-ping jq make net-tools npm pwgen s3cmd ssh unzip wget \
        libasound2 libgbm-dev libgconf-2-4 libgtk2.0-0 libgtk-3-0 libnotify-dev libnss3 libxss1 libxtst6 xauth xvfb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV SOPS_VERSION="3.7.3"
RUN wget --progress=dot:giga "https://github.com/mozilla/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux" && \
    install -Tm 755 "sops-v${SOPS_VERSION}.linux" /usr/local/bin/sops && \
    rm "sops-v${SOPS_VERSION}.linux"

ENV KUBECTL_VERSION "1.24.4"
RUN wget --progress=dot:giga "https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    install -Tm 755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

ENV KUBELOGIN_VERSION="1.24.0"
RUN wget --progress=dot:giga "https://github.com/int128/kubelogin/releases/download/v${KUBELOGIN_VERSION}/kubelogin_linux_amd64.zip" && \
    unzip kubelogin_linux_amd64.zip && \
    install -Tm 755 kubelogin /usr/local/bin/kubectl-oidc_login && \
    rm kubelogin kubelogin_linux_amd64.zip LICENSE README.md

ENV HELM_VERSION "3.8.0"
RUN wget --progress=dot:giga "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" && \
    tar -zxvf "helm-v${HELM_VERSION}-linux-amd64.tar.gz" && \
    install -Tm 755 linux-amd64/helm /usr/local/bin/helm && \
    rm -rf linux-amd64 "helm-v${HELM_VERSION}-linux-amd64.tar.gz"

ENV XDG_DATA_HOME=/root/.config
RUN helm plugin install https://github.com/databus23/helm-diff --version v3.5.0
RUN helm plugin install https://github.com/jkroepke/helm-secrets --version v3.12.0

ENV HELMFILE_VERSION "0.154.0"
RUN wget --progress=dot:giga "https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION}_linux_amd64.tar.gz" && \
    tar -zxvf "helmfile_${HELMFILE_VERSION}_linux_amd64.tar.gz" helmfile && \
    install -Tm 755 helmfile /usr/local/bin/helmfile && \
    rm helmfile "helmfile_${HELMFILE_VERSION}_linux_amd64.tar.gz"

ENV YQ_VERSION "4.26.1"
RUN wget --progress=dot:giga "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" && \
    install -Tm 755 yq_linux_amd64 /usr/local/bin/yq4 && \
    rm yq_linux_amd64

USER ubuntu

ENV ROOT="/apps"

COPY --chown=ubuntu:ubuntu ./Makefile /apps/tests/Makefile
COPY --chown=ubuntu:ubuntu ./common /apps/tests/common

WORKDIR /apps/tests

RUN make dep

COPY --chown=ubuntu:ubuntu  ./ /apps/tests

RUN make gen
