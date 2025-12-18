# Container to run unit tests
FROM ubuntu:24.04 AS unit
LABEL org.opencontainers.image.source=https://github.com/elastisys/compliantkubernetes-apps

ENV DEBIAN_FRONTEND="noninteractive"
ENV LANGUAGE="en"
ENV LANG="en_US.utf8"

RUN apt-get -q=2 update && \
    apt-get -q=2 install apache2-utils curl dnsutils gettext-base git gpg iputils-ping jq locales make net-tools parallel pwgen python3-venv s3cmd ssh unzip >/dev/null && \
    apt-get -q=2 clean && \
    rm -rf /var/lib/apt/lists/* && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

ENV HELM_DATA_HOME="/usr/local/share/helm"
ENV DOCS_PATH="/usr/local/share/docs"

COPY ./tests/common/install-tools.bash /opt/install-tools.bash
RUN BATS_CORE_VERSION="1.11.1@sha256:b036dd11d2d22ff82a191233429f9d3e33c62ec6d3e6769243e7dfa3e7ca9908" \
    BATS_ASSERT_REV="697471b7a89d3ab38571f38c6c7c4b460d1f5e35" \
    BATS_DETIK_REV="ce86871d7fdaed7f31b0e11e228b7b91a58ac1cc" \
    BATS_FILE_REV="c0bb8ef329908cbb2c456c05ebb785d44553f7cd" \
    BATS_MOCK_REV="48fce74482a4d2bb879b904ccab31b6bc98e3224" \
    BATS_SUPPORT_REV="0954abb9925cad550424cebca2b99255d4eabe96" \
    GOMPLATE_VERSION="4.3.1@sha256:9f6c008a8ffa2574ce404acd31dd4efbdbde7aeaa867f0b8fd8dccd298cd282e"  \
    HELM_VERSION="3.18.4@sha256:84d06a0f5ba17fd9c4d9912613453cdaa95a4f59c8baf20c195b74310b009ea6" \
    HELM_DIFF_VERSION="3.10.0@sha256:16db94ce5ad7a6cf55118b723111defdb7dc2b227f8f0886d6fdec2545fd02de" \
    HELM_SECRETS_VERSION="4.6.5" \
    HELMFILE_VERSION="0.171.0@sha256:8bd28d832b6d9fde9e770925a03d251a7672737b3248293bf52c0b3dfcc64e73" \
    KUBECTL_VERSION="1.33.6@sha256:d25d9b63335c038333bed785e9c6c4b0e41d791a09cac5f3e8df9862c684afbe" \
    KUBECONFORM_VERSION="0.6.7@sha256:9e867e86e277de971bed3cfe46cf07f1d08db212e9188389670b3685c38281e7" \
    KUBELOGIN_VERSION="1.32.3@sha256:d5288ae63d8d7e8cc5db3bc97ac3e3f979cf43b8aeb3e831acb27622b5d843b3" \
    OPA_VERSION="0.57.1@sha256:5212d513dad9bd90bc67743d7812e5ec7019b2a994f30c0d8dbb2b2c6772f094" \
    PROMTOOL_VERSION="3.6.0@sha256:3e7460d042ddc03c69bf9234c8495c0097d8533cef8add1e2ca04a4f9953488e" \
    SOPS_VERSION="3.10.1@sha256:1bc9fbce48e3fcc7e684d604d50f7c56721b6cd2d27f96ec74b8b56b5a96c942" \
    YAJSV_VERSION="1.4.1@sha256:4bd6d2b1d6292ab1f7ba63db83c182a603a790d431429cf71f05cb0fcc677def" \
    YQ_VERSION="4.45.1@sha256:654d2943ca1d3be2024089eb4f270f4070f491a0610481d128509b2834870049" \
    /opt/install-tools.bash do_unit

ENV PATH="${DOCS_PATH}/.venv/bin:${PATH}"

# Container to run integration and end-to-end tests
FROM unit AS main

ENV DIST="noble"

RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/keyrings/microsoft.gpg > /dev/null && \
    chmod go+r /etc/apt/keyrings/microsoft.gpg && \
    echo "Types: deb \n\
URIs: https://packages.microsoft.com/repos/azure-cli/ \n\
Suites: ${DIST} \n\
Components: main \n\
Architectures: $(dpkg --print-architecture) \n\
Signed-by: /etc/apt/keyrings/microsoft.gpg" | tee /etc/apt/sources.list.d/azure-cli.sources

ARG AZ_VERSION=2.63.0
RUN apt-get -q=2 update && \
    apt-get -q=2 install azure-cli=${AZ_VERSION}-1~${DIST} buildah docker.io libasound2t64 libatk1.0-0 libatk-bridge2.0-0 libcanberra-gtk-module \
    libcanberra-gtk3-module libcups2 libgbm-dev libgbm1 libglib2.0-0 libgtk2.0-0 libgtk2.0-0t64 libgtk-3-0 \
    libgtk-3-0t64 libnotify-dev libnss3 libxss1 libxtst6 podman-remote skopeo socat xauth xvfb zstd >/dev/null && \
    apt-get -q=2 clean && \
    rm -rf /var/lib/apt/lists/* && \
    ln -s /usr/bin/podman-remote /usr/bin/podman

ENV NODE_PATH="/usr/local/lib/node_modules"
ENV PATH="${PATH}:${NODE_PATH}/.bin"
ENV CYPRESS_CACHE_FOLDER=/usr/local/lib/cypress

RUN KIND_VERSION="0.30.0@sha256:517ab7fc89ddeed5fa65abf71530d90648d9638ef0c4cde22c2c11f8097b8889" \
    VELERO_VERSION="1.13.0@sha256:1b6662eb06ecb974c96edd32296cc334c51af5e6c4d2d19408a285a20b771aba" \
    BUN_VERSION="1.3.5@sha256:a56093cbdd2efc7290a744ccc39971dcc4be52c5732be15c7fb1465cc119c8de" \
    /opt/install-tools.bash do_main

WORKDIR /opt/node-packages
COPY ./tests/package.json ./tests/bun.lock ./
RUN bun install --frozen-lockfile --production && \
    mv node_modules "${NODE_PATH}" && \
    cypress verify
WORKDIR /
