#!/usr/bin/env bash
set -euo pipefail

TMPDIR=$(mktemp -d)
trap 'rm -rf $TMPDIR' EXIT

cd "$TMPDIR"

# --------- Installers for the 'unit' stage ----------
# NOTE: functions prefixed with 'unit_install_' will be automatically executed in the 'unit' stage.

unit_install_bats() {
  _parse_version "${BATS_CORE_VERSION}"
  git clone -q --depth 1 https://github.com/bats-core/bats-core.git --branch "v${VERSION}" "${TMPDIR}/bats-core"
  "${TMPDIR}/bats-core/install.sh" /usr/local
  echo "${SHA}  /usr/local/bin/bats" | sha256sum -c -

  _git_clone_revision https://github.com/bats-core/bats-assert.git /usr/local/lib/bats/assert "${BATS_ASSERT_REV}"
  _git_clone_revision https://github.com/bats-core/bats-detik.git /usr/local/lib/bats/detik "${BATS_DETIK_REV}"
  _git_clone_revision https://github.com/bats-core/bats-file.git /usr/local/lib/bats/file "${BATS_FILE_REV}"
  _git_clone_revision https://github.com/grayhemp/bats-mock.git /usr/local/lib/bats/mock "${BATS_MOCK_REV}"
  _git_clone_revision https://github.com/bats-core/bats-support.git /usr/local/lib/bats/support "${BATS_SUPPORT_REV}"
  echo "✓ bats installed"
}

unit_install_docs() {
  git clone -q --depth 1 --recurse-submodules --shallow-submodules git@github.com:elastisys/welkin.git "${DOCS_PATH}"
  python3 -m venv "${DOCS_PATH}/.venv"
  pushd "${DOCS_PATH}" >/dev/null
  ./.venv/bin/pip install --no-cache-dir --quiet -r requirements.txt
  echo "✓ docs installed"
}

unit_install_gomplate() {
  _parse_version "${GOMPLATE_VERSION}"
  curl -LOs "https://github.com/hairyhenderson/gomplate/releases/download/v${VERSION}/gomplate_linux-amd64"
  echo "${SHA}  gomplate_linux-amd64" | sha256sum -c -
  install -Tm 755 gomplate_linux-amd64 /usr/local/bin/gomplate
  echo "✓ gomplate installed"
}

unit_install_helm() {
  _parse_version "${HELM_VERSION}"
  curl -LOs "https://get.helm.sh/helm-v${VERSION}-linux-amd64.tar.gz"
  tar -zxf "helm-v${VERSION}-linux-amd64.tar.gz" linux-amd64/helm
  echo "${SHA}  linux-amd64/helm" | sha256sum -c -
  install -Tm 755 linux-amd64/helm /usr/local/bin/helm
  echo "✓ helm installed"

  _parse_version "${HELM_DIFF_VERSION}"
  helm plugin install https://github.com/databus23/helm-diff --version "v${VERSION}" >/dev/null
  echo "${SHA}  ${HELM_DATA_HOME}/plugins/helm-diff/bin/diff" | sha256sum -c -
  echo "✓ helm-diff installed"

  helm plugin install https://github.com/jkroepke/helm-secrets --version "v${HELM_SECRETS_VERSION}" >/dev/null
  echo "✓ helm-secrets installed"
}

unit_install_helmfile() {
  _parse_version "${HELMFILE_VERSION}"
  curl -LOs "https://github.com/helmfile/helmfile/releases/download/v${VERSION}/helmfile_${VERSION}_linux_amd64.tar.gz"
  tar -zxf "helmfile_${VERSION}_linux_amd64.tar.gz" helmfile
  echo "${SHA}  helmfile" | sha256sum -c -
  install -Tm 755 helmfile /usr/local/bin/helmfile
  echo "✓ helmfile installed"
}

unit_install_kubectl() {
  _parse_version "${KUBECTL_VERSION}"
  curl -LOs "https://dl.k8s.io/release/v${VERSION}/bin/linux/amd64/kubectl"
  echo "${SHA}  kubectl" | sha256sum -c -
  install -Tm 755 kubectl /usr/local/bin/kubectl
  echo "✓ kubectl installed"
}

unit_install_kubeconform() {
  _parse_version "${KUBECONFORM_VERSION}"
  curl -LOs "https://github.com/yannh/kubeconform/releases/download/v${VERSION}/kubeconform-linux-amd64.tar.gz"
  tar -zxf kubeconform-linux-amd64.tar.gz kubeconform
  echo "${SHA}  kubeconform" | sha256sum -c -
  install -Tm 755 kubeconform /usr/local/bin/kubeconform
  echo "✓ kubeconform installed"
}

unit_install_kubelogin() {
  _parse_version "${KUBELOGIN_VERSION}"
  curl -LOs "https://github.com/int128/kubelogin/releases/download/v${VERSION}/kubelogin_linux_amd64.zip"
  unzip -q kubelogin_linux_amd64.zip
  echo "${SHA}  kubelogin" | sha256sum -c -
  install -Tm 755 kubelogin /usr/local/bin/kubectl-oidc_login
  echo "✓ kubelogin installed"
}

unit_install_opa() {
  _parse_version "${OPA_VERSION}"
  curl -LOs "https://github.com/open-policy-agent/opa/releases/download/v${VERSION}/opa_linux_amd64"
  echo "${SHA}  opa_linux_amd64" | sha256sum -c -
  install -Tm 755 opa_linux_amd64 /usr/local/bin/opa
  echo "✓ opa installed"
}

unit_install_promtool() {
  _parse_version "${PROMTOOL_VERSION}"
  curl -fsSL "https://github.com/prometheus/prometheus/releases/download/v${VERSION}/prometheus-${VERSION}.linux-amd64.tar.gz" |
    tar -zxf - "prometheus-${VERSION}.linux-amd64/promtool" --strip-components=1
  echo "${SHA}  promtool" | sha256sum -c -
  install -Tm 755 promtool /usr/local/bin/promtool
  echo "✓ promtool installed"
}

unit_install_sops() {
  _parse_version "${SOPS_VERSION}"
  curl -LOs "https://github.com/getsops/sops/releases/download/v${VERSION}/sops-v${VERSION}.linux.amd64"
  echo "${SHA}  sops-v${VERSION}.linux.amd64" | sha256sum -c -
  install -Tm 755 "sops-v${VERSION}.linux.amd64" /usr/local/bin/sops
  echo "✓ sops installed"
}

unit_install_yajsv() {
  _parse_version "${YAJSV_VERSION}"
  curl -LOs "https://github.com/neilpa/yajsv/releases/download/v${VERSION}/yajsv.linux.amd64"
  echo "${SHA}  yajsv.linux.amd64" | sha256sum -c -
  install -Tm 755 yajsv.linux.amd64 /usr/local/bin/yajsv
  echo "✓ yajsv installed"
}

unit_install_yq() {
  _parse_version "${YQ_VERSION}"
  curl -LOs "https://github.com/mikefarah/yq/releases/download/v${VERSION}/yq_linux_amd64"
  echo "${SHA}  yq_linux_amd64" | sha256sum -c -
  install -Tm 755 yq_linux_amd64 /usr/local/bin/yq
  echo "✓ yq installed"
}

# --------- Installers for the 'main' stage ----------
# NOTE: functions prefixed with 'main_install_' will be automatically executed in the 'main' stage.

main_install_kind() {
  _parse_version "${KIND_VERSION}"
  curl -LOs "https://github.com/kubernetes-sigs/kind/releases/download/v${VERSION}/kind-linux-amd64"
  echo "${SHA}  kind-linux-amd64" | sha256sum -c -
  install -Tm 755 kind-linux-amd64 /usr/local/bin/kind
  echo "✓ kind installed"
}

main_install_velero() {
  _parse_version "${VELERO_VERSION}"
  curl -LOs "https://github.com/vmware-tanzu/velero/releases/download/v${VERSION}/velero-v${VERSION}-linux-amd64.tar.gz"
  tar -zxf "velero-v${VERSION}-linux-amd64.tar.gz" "velero-v${VERSION}-linux-amd64"
  echo "${SHA}  velero-v${VERSION}-linux-amd64/velero" | sha256sum -c -
  install -Tm 755 "velero-v${VERSION}-linux-amd64/velero" /usr/local/bin/velero
  echo "✓ velero installed"
}

main_install_bun() {
  _parse_version "${BUN_VERSION}"
  curl -LOs "https://github.com/oven-sh/bun/releases/download/bun-v${VERSION}/bun-linux-x64.zip"
  unzip -q bun-linux-x64.zip
  echo "${SHA}  bun-linux-x64/bun" | sha256sum -c -
  install -Tm 755 bun-linux-x64/bun /usr/local/bin/bun
  ln -sf /usr/local/bin/bun /usr/local/bin/node
  echo "✓ bun installed"
}

# --------- Utility functions ----------

_git_clone_revision() {
  if [[ $# -lt 3 ]]; then
    echo "usage: _git_clone_revision <repo> <destination_dir> <revision>" >&2
    return 1
  fi

  local -r repo="${1}"
  local -r dest="${2}"
  local -r rev="${3}"

  git clone -q --depth 1 "${repo}" "${dest}"
  pushd "${dest}" >/dev/null
  git reset -q --hard "${rev}"
  git clean -q -fd
  popd >/dev/null
}

_parse_version() {
  VERSION="${1%%@sha256:*}"
  SHA="${1#*@sha256:}"
}

usage() {
  echo "fatal: You must specify a stage to install.

usage: $0 <stage>

supported stages:
  - unit
  - main"
}

dispatch() {
  local stage install_fns
  stage="${1:-}"

  case "${stage}" in
  unit | main)
    # Re-export shell options so we fail on error
    export SHELLOPTS TMPDIR

    # Export utility + installer functions
    mapfile -t install_fns < <(declare -F | grep -oP ".+\K${stage}_install_.+")
    export -f _git_clone_revision _parse_version "${install_fns[@]}"

    echo "Installing ${stage} tools in parallel..."
    git config --global advice.detachedHead false
    parallel -j "$(nproc)" --will-cite --halt now,fail=1 ::: "${install_fns[@]}"
    ;;
  *)
    usage 1>&2
    ;;
  esac
}

dispatch "${@}"
