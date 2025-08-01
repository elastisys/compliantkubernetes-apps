# Container to run unit tests
FROM ubuntu:24.04 AS unit
LABEL org.opencontainers.image.source=https://github.com/elastisys/compliantkubernetes-apps

ARG DEBIAN_FRONTEND="noninteractive"
ENV LANGUAGE="en"
ENV LANG="en_US.utf8"
ARG TZ="Etc/UTC"

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y apache2-utils curl dnsutils gettext-base parallel git gpg iputils-ping jq locales make net-tools npm pwgen s3cmd ssh unzip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

ENV NODE_PATH="/usr/local/lib/node_modules"

ARG GOMPLATE_VERSION="4.3.1"
RUN curl -LOs "https://github.com/hairyhenderson/gomplate/releases/download/v${GOMPLATE_VERSION}/gomplate_linux-amd64" && \
    install -Tm 755 gomplate_linux-amd64 /usr/local/bin/gomplate && \
    rm gomplate_linux-amd64

ARG HELM_VERSION="3.17.2"
ENV HELM_DATA_HOME="/usr/local/share/helm"
RUN curl -LOs "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" && \
    tar -zxvf "helm-v${HELM_VERSION}-linux-amd64.tar.gz" linux-amd64/helm && \
    install -Tm 755 linux-amd64/helm /usr/local/bin/helm && \
    rm -rf linux-amd64 "helm-v${HELM_VERSION}-linux-amd64.tar.gz"

ARG HELM_DIFF_VERSION="3.10.0"
RUN helm plugin install https://github.com/databus23/helm-diff --version "v${HELM_DIFF_VERSION}" > /dev/null

ARG HELM_SECRETS_VERSION="4.6.3"
RUN helm plugin install https://github.com/jkroepke/helm-secrets --version "v${HELM_SECRETS_VERSION}" > /dev/null

ARG HELMFILE_VERSION="0.171.0"
RUN curl -LOs "https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION}_linux_amd64.tar.gz" && \
    tar -zxvf "helmfile_${HELMFILE_VERSION}_linux_amd64.tar.gz" helmfile && \
    install -Tm 755 helmfile /usr/local/bin/helmfile && \
    rm helmfile "helmfile_${HELMFILE_VERSION}_linux_amd64.tar.gz"

ENV JSONSCHEMA2MD_VERSION="8.0.2"
RUN npm install --global "@adobe/jsonschema2md@${JSONSCHEMA2MD_VERSION}"

ARG KUBECTL_VERSION="1.31.9"
RUN curl -LOs "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    install -Tm 755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

ARG KUBECONFORM_VERSION="0.6.7"
RUN curl -LOs "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz" && \
    tar -zxvf kubeconform-linux-amd64.tar.gz kubeconform && \
    install -Tm 755 kubeconform /usr/local/bin/kubeconform && \
    rm kubeconform-linux-amd64.tar.gz kubeconform

ARG KUBELOGIN_VERSION="1.32.3"
RUN curl -LOs "https://github.com/int128/kubelogin/releases/download/v${KUBELOGIN_VERSION}/kubelogin_linux_amd64.zip" && \
    unzip kubelogin_linux_amd64.zip && \
    install -Tm 755 kubelogin /usr/local/bin/kubectl-oidc_login && \
    rm kubelogin kubelogin_linux_amd64.zip LICENSE README.md

ARG OPA_VERSION="0.57.1"
RUN curl -LOs "https://github.com/open-policy-agent/opa/releases/download/v${OPA_VERSION}/opa_linux_amd64" && \
    install -Tm 755 opa_linux_amd64 /usr/local/bin/opa && \
    rm opa_linux_amd64

ARG SOPS_VERSION="3.10.1"
RUN curl -LOs "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64" && \
    install -Tm 755 "sops-v${SOPS_VERSION}.linux.amd64" /usr/local/bin/sops && \
    rm "sops-v${SOPS_VERSION}.linux.amd64"

ARG YAJSV_VERSION="1.4.1"
RUN curl -LOs "https://github.com/neilpa/yajsv/releases/download/v${YAJSV_VERSION}/yajsv.linux.amd64" && \
    install -Tm 755 yajsv.linux.amd64 /usr/local/bin/yajsv && \
    rm yajsv.linux.amd64

ARG YQ_VERSION="4.45.1"
RUN curl -LOs "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" && \
    install -Tm 755 yq_linux_amd64 /usr/local/bin/yq && \
    rm yq_linux_amd64

ARG BATS_CORE_VERSION="1.11.1"
RUN git clone --depth 1 https://github.com/bats-core/bats-core.git --branch "v${BATS_CORE_VERSION}" /tmp/bats-core && ./tmp/bats-core/install.sh /usr/local && rm -rf /tmp/bats-core

# Currently all from main as most do not have current releases
RUN git clone --depth 1 https://github.com/bats-core/bats-assert.git /usr/local/lib/bats/assert
RUN git clone --depth 1 https://github.com/bats-core/bats-detik.git /usr/local/lib/bats/detik
RUN git clone --depth 1 https://github.com/bats-core/bats-file.git /usr/local/lib/bats/file
RUN git clone --depth 1 https://github.com/grayhemp/bats-mock.git /usr/local/lib/bats/mock
RUN git clone --depth 1 https://github.com/bats-core/bats-support.git /usr/local/lib/bats/support

ENV DOCS_PATH="/usr/local/share/docs"
RUN git clone --depth 1 https://github.com/elastisys/welkin.git "${DOCS_PATH}" && \
    chmod --recursive a+w "${DOCS_PATH}"

FROM ubuntu:24.04 AS node-deps

RUN apt-get update && apt-get install -y npm && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /welkin-test
COPY ./tests/package.json ./tests/package-lock.json ./
RUN npm install --global --omit dev

# Container to run integration and end-to-end tests
FROM unit AS main

RUN apt-get update && \
    apt-get install -y buildah docker.io npm flatpak-xdg-utils libasound2t64 libatk1.0-0 libatk-bridge2.0-0 libcanberra-gtk-module libcanberra-gtk3-module libcups2 libgbm-dev libgbm1 libglib2.0-0 libgtk2.0-0 libgtk2.0-0t64 libgtk-3-0 libgtk-3-0t64 libnotify-dev libnss3 libxss1 libxtst6 podman-remote skopeo xauth xvfb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    ln -s /usr/bin/podman-remote /usr/bin/podman && \
    mv /usr/bin/xdg-open /usr/bin/xdg-open-backup && \
    ln -s /usr/libexec/flatpak-xdg-utils/xdg-open /usr/bin/xdg-open

ARG KIND_VERSION="0.27.0"
RUN curl -LOs "https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/kind-linux-amd64" && \
    install -Tm 755 kind-linux-amd64 /usr/local/bin/kind && \
    rm kind-linux-amd64

ARG VELERO_VERSION="1.13.0"
RUN curl -LOs "https://github.com/vmware-tanzu/velero/releases/download/v${VELERO_VERSION}/velero-v${VELERO_VERSION}-linux-amd64.tar.gz" && \
    tar -zxvf "velero-v${VELERO_VERSION}-linux-amd64.tar.gz" "velero-v${VELERO_VERSION}-linux-amd64" && \
    install -Tm 755 "velero-v${VELERO_VERSION}-linux-amd64/velero" /usr/local/bin/velero && \
    rm -r "velero-v${VELERO_VERSION}-linux-amd64.tar.gz" "velero-v${VELERO_VERSION}-linux-amd64"

COPY --from=node-deps /usr/local/lib/node_modules/welkin-test/node_modules /usr/local/lib/node_modules
ENV PATH="$PATH:/usr/local/lib/node_modules/.bin"
ENV CYPRESS_CACHE_FOLDER=/usr/local/lib/cypress
RUN cypress install && cypress verify
