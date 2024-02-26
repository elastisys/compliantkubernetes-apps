FROM ubuntu:rolling AS base
LABEL org.opencontainers.image.source https://github.com/elastisys/compliantkubernetes-apps

ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=Etc/UTC

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y apache2-utils bats curl dnsutils gettext-base git gpg iputils-ping jq make net-tools pwgen s3cmd ssh unzip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV SOPS_VERSION="3.8.1"
RUN curl -LOs "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64" && \
    install -Tm 755 "sops-v${SOPS_VERSION}.linux.amd64" /usr/local/bin/sops && \
    rm "sops-v${SOPS_VERSION}.linux.amd64"

ENV KUBECTL_VERSION "1.28.6"
RUN curl -LOs "https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    install -Tm 755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

ENV KUBECONFORM_VERSION "v0.6.3"
RUN curl -LOs "https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz" && \
    tar -zxvf kubeconform-linux-amd64.tar.gz kubeconform && \
    install -Tm 755 kubeconform /usr/local/bin/kubeconform && \
    rm kubeconform-linux-amd64.tar.gz kubeconform

ENV KUBELOGIN_VERSION="1.28.0"
RUN curl -LOs "https://github.com/int128/kubelogin/releases/download/v${KUBELOGIN_VERSION}/kubelogin_linux_amd64.zip" && \
    unzip kubelogin_linux_amd64.zip && \
    install -Tm 755 kubelogin /usr/local/bin/kubectl-oidc_login && \
    rm kubelogin kubelogin_linux_amd64.zip LICENSE README.md

ENV HELM_VERSION "3.13.3"
RUN curl -LOs "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" && \
    tar -zxvf "helm-v${HELM_VERSION}-linux-amd64.tar.gz" linux-amd64/helm && \
    install -Tm 755 linux-amd64/helm /usr/local/bin/helm && \
    rm -rf linux-amd64 "helm-v${HELM_VERSION}-linux-amd64.tar.gz"

ENV HELMFILE_VERSION "0.162.0"
RUN curl -LOs "https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION}_linux_amd64.tar.gz" && \
    tar -zxvf "helmfile_${HELMFILE_VERSION}_linux_amd64.tar.gz" helmfile && \
    install -Tm 755 helmfile /usr/local/bin/helmfile && \
    rm helmfile "helmfile_${HELMFILE_VERSION}_linux_amd64.tar.gz"

ENV OPA_VERSION "v0.58.0"
RUN curl -LOs "https://github.com/open-policy-agent/opa/releases/download/${OPA_VERSION}/opa_linux_amd64" && \
    install -Tm 755 opa_linux_amd64 /usr/local/bin/opa && \
    rm opa_linux_amd64

ENV YQ_VERSION "4.42.1"
RUN curl -LOs "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" && \
    install -Tm 755 yq_linux_amd64 /usr/local/bin/yq4 && \
    rm yq_linux_amd64

# Match user between container and host

ARG UID=1000
ARG GID=1000

RUN usermod -u "${UID}" ubuntu
RUN groupmod -g "${GID}" ubuntu

USER ubuntu

RUN helm plugin install https://github.com/databus23/helm-diff --version v3.9.4 > /dev/null
RUN helm plugin install https://github.com/jkroepke/helm-secrets --version v4.5.1 > /dev/null

# Container to run unit tests only
FROM base AS unit

ENV ROOT="/apps"

COPY --chown=ubuntu:ubuntu tests/Makefile tests/package.json tests/package-lock.json /apps/tests/

WORKDIR /apps/tests

RUN CK8S_TESTS_BUILD=true make dep-bats dep-docs

COPY --chown=ubuntu:ubuntu . /apps/

RUN make gen

# Container to run all tests
FROM base AS main

USER root

RUN apt-get update && \
    apt-get install -y npm libasound2 libgbm-dev libgtk2.0-0 libgtk-3-0 libnotify-dev libnss3 libxss1 libxtst6 xauth xvfb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

USER ubuntu

ENV ROOT="/apps"

COPY --chown=ubuntu:ubuntu tests/Makefile tests/package.json tests/package-lock.json /apps/tests/

WORKDIR /apps/tests

RUN CK8S_TESTS_BUILD=true make dep

COPY --chown=ubuntu:ubuntu . /apps/

RUN make gen
