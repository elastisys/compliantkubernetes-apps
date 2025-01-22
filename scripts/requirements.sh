#!/usr/bin/env bash

# Requirements installer for containers
# The goal is to make it usable as _the_ way to install requirements but we need to start somewhere.

set -euo pipefail
shopt -s extglob

# purl variables
declare -a packages
declare -A types
declare -A namespaces
declare -A names
declare -A versions
declare -A qualifiers
declare -A subpaths

# TODO: Remove when actually used
export qualifiers
export subpaths

# others mappings
declare -A targets
declare -A sources
declare -A intermediates

# <package> <target> <source> [intermediate]
parse-mappings() {
  local package="${1}" target="${2}" source="${3}" intermediate="${4:-}"

  targets["${package}"]="${target}"
  sources["${package}"]="${source}"
  intermediates["${package}"]="${intermediate}"
}

# parse-mappings /usr/local/bin/gomplate "https://github.com/hairyhenderson/gomplate/releases/download/v\${version}/gomplate_linux-amd64"
parse-mappings golang/helm.sh/helm/v3 /usr/local/bin/helm "https://get.helm.sh/helm-v\${version}-linux-amd64.tar.gz" linux-amd64/helm
# helm plugin install https://github.com/databus23/helm-diff --version "v${HELM_DIFF_VERSION}" >/dev/null
# helm plugin install https://github.com/jkroepke/helm-secrets --version "v${HELM_SECRETS_VERSION}" >/dev/null
parse-mappings golang/github.com/helmfile/helmfile /usr/local/bin/helmfile "https://github.com/helmfile/helmfile/releases/download/v\${version}/helmfile_\${version}_linux_amd64.tar.gz" helmfile
parse-mappings generic//kind /usr/local/bin/kind "https://github.com/kubernetes-sigs/kind/releases/download/v\${version}/kind-linux-amd64"
parse-mappings generic//kubectl /usr/local/bin/kubectl "https://storage.googleapis.com/kubernetes-release/release/v\${version}/bin/linux/amd64/kubectl"
# parse-mappings /usr/local/bin/kubeconform "https://github.com/yannh/kubeconform/releases/download/v\${version}/kubeconform-linux-amd64.tar.gz" kubeconform
# parse-mappings /usr/local/bin/kubectl-oidc_login "https://github.com/int128/kubelogin/releases/download/v\${version}/kubelogin_linux_amd64.zip" kubelogin
# parse-mappings /usr/local/bin/opa "https://github.com/open-policy-agent/opa/releases/download/\${version}/opa_linux_amd64"
parse-mappings golang/getsops/sops/v3 /usr/local/bin/sops "https://github.com/getsops/sops/releases/download/v\${version}/sops-v\${version}.linux.amd64"
parse-mappings golang/github.com/neilpa/yajsv /usr/local/bin/yajsv "https://github.com/neilpa/yajsv/releases/download/v\${version}/yajsv.linux.amd64"
parse-mappings golang/github.com/vmware-tanzu/velero /usr/local/bin/velero "https://github.com/vmware-tanzu/velero/releases/download/v\${version}/velero-v\${version}-linux-amd64.tar.gz" "velero-v\${version}-linux-amd64/velero"
parse-mappings golang/github.com/mikefarah/yq/v4 /usr/local/bin/yq4 "https://github.com/mikefarah/yq/releases/download/v\${version}/yq_linux_amd64"

# <file>
parse-requirements() {
  local file="${1}"

  if ! [[ -f "${file}" ]]; then
    echo "failure, not a file"
    return 1
  fi

  local -a rows
  readarray rows <"${1}"

  for row in "${rows[@]}"; do
    parse-package "${row}"
  done
}

# <purl>
parse-package() {
  local purl="${1}" remainder component

  purl="${purl##+([[:space:]])}"
  purl="${purl%%+([[:space:]])}"

  remainder="${purl}"

  if [[ "${remainder}" =~ "#" ]]; then
    component="${purl##*"#"}"
    component="${component##"/"}"
    # TODO: Split, discard dot and empty segments, decode, and rejoin
    subpaths["${purl}"]="${component%%"/"}"
    remainder="${purl%"#"*}"
  fi

  if [[ "${remainder}" =~ "?" ]]; then
    # TODO: Manage key value pairs
    qualifiers["${purl}"]="${remainder##*"?"}"
    remainder="${remainder%"?"*}"
  fi

  component="${remainder%%":"*}"
  if [[ "${component}" != "pkg" ]]; then
    echo "invalid purl: invalid scheme"
    return
  fi
  remainder="${remainder#*":"}"

  remainder="${remainder##"/"}"
  remainder="${remainder%%"/"}"

  component="${remainder%%"/"*}"
  if [[ -z "${component}" ]]; then
    echo "invalid purl: missing type"
    return
  fi
  types["${purl}"]="${component}"
  remainder="${remainder#*"/"}"

  if [[ "${remainder}" =~ "@" ]]; then
    # TODO: Decode
    versions["${purl}"]="${remainder##*"@"}"
    remainder="${remainder%"@"*}"
  fi

  component="${remainder##*"/"}"
  if [[ -z "${component}" ]]; then
    echo "invalid purl: missing name"
    return
  fi
  # TODO: Decode and normalise
  names["${purl}"]="${component}"
  remainder="${remainder%"/"*}"

  if [[ "${remainder}" =~ "/" ]]; then
    # TODO: Split, discard empty segments, decode, normalise, and rejoin
    namespaces["${purl}"]="${remainder}"
  fi

  packages+=("${purl}")

  # echo "${purl} - pkg: ${types["${purl}"]} / ${namespaces["${purl}"]:-} / ${names["${purl}"]} @ ${versions["${purl}"]:-} ? ${qualifiers["${purl}"]:-} # ${subpaths["${purl}"]:-}"
}

# <packages...>
install-from-apt() {
  apt-get update
  apt-get upgrade -y
  apt-get install -y "${@}"
  apt-get clean
  rm -rf /var/lib/apt/lists/*
}

# <target> <source> <checksum-bin>
install-from-bin() {
  local target="${1}" source="${2}" checksum_bin="${4:-}" checksum

  echo "installing ${target}"

  if [[ -e "${target}" ]] && [[ -n "${checksum_bin}" ]]; then
    checksum="$(sha256sum "${target}")"
    if [[ "${checksum_bin}" == "${checksum%%" "*}" ]]; then
      echo "- installed ${target} matches desired binary checksum, skipping"
      return
    fi
  fi

  echo "- fetching ${target}"
  curl -#LOs "${source}"

  checksum="$(sha256sum "${source##*"/"}")"
  if [[ -n "${checksum_bin}" ]]; then
    echo "- checking binary checksum ${source##*"/"}"
    if [[ "${checksum_bin}" != "${checksum%%" "*}" ]]; then
      echo "- error: ${source##*"/"} does not match desired binary checksum, skipping"
      return
    fi
  else
    echo "- warning: missing desired binary checksum, skipping validation (bin sha256:${checksum%%" "*})"
  fi

  install -Tm 755 "${source##*"/"}" "${target}"
  rm -rf "${source##*"/"}"

  echo "- installed ${target}"
}

# <target> <source> <intermediate> <checksum-bin> <checksum-pkg>
install-from-tar() {
  local target="${1}" source="${2}" intermediate="${3}" checksum_bin="${4:-}" checksum_pkg="${5:-}" checksum

  echo "installing ${target}"

  if [[ -e "${target}" ]] && [[ -n "${checksum_bin}" ]]; then
    checksum="$(sha256sum "${target}")"
    if [[ "${checksum_bin}" == "${checksum%%" "*}" ]]; then
      echo "- installed ${target} matches desired binary checksum, skipping"
      return
    fi
  fi

  echo "- fetching ${target}"
  curl -#LO "${source}"

  checksum="$(sha256sum "${source##*"/"}")"
  if [[ -n "${checksum_pkg}" ]]; then
    echo "- checking package checksum ${source##*"/"}"
    if [[ "${checksum_pkg}" != "${checksum%%" "*}" ]]; then
      echo "- error: ${source##*"/"} does not match desired package checksum, skipping"
      return
    fi
  else
    echo "- warning: missing desired package checksum, skipping validation (pkg sha256:${checksum%%" "*})"
  fi

  tar -xf "${source##*"/"}" "${intermediate}"

  checksum="$(sha256sum "${intermediate}")"
  if [[ -n "${checksum_bin}" ]]; then
    echo "- checking binary checksum ${intermediate}"
    if [[ "${checksum_bin}" != "${checksum%%" "*}" ]]; then
      echo "- error: ${intermediate} does not match desired binary checksum, skipping"
      return
    fi
  else
    echo "- warning: missing desired binary checksum, skipping validation (bin sha256:${checksum%%" "*})"
  fi

  install -Tm 755 "${intermediate}" "${target}"
  rm -rf "${source##*"/"}" "${intermediate%%"/"*}"

  echo "- installed ${target}"
}

# <target> <source> <intermediate> <checksum-pkg> <checksum-bin>
install-from-zip() {
  local target="${1}" source="${2}" intermediate="${3}" checksum_bin="${4:-}" checksum_pkg="${5:-}" checksum

  echo "installing ${target}"

  if [[ -e "${target}" ]] && [[ -n "${checksum_bin}" ]]; then
    checksum="$(sha256sum "${target}")"
    if [[ "${checksum_bin}" == "${checksum%%" "*}" ]]; then
      echo "- installed ${target} matches desired binary checksum, skipping"
      return
    fi
  fi

  echo "- fetching ${target}"
  curl -#LOs "${source}"

  checksum="$(sha256sum "${source##*"/"}")"
  if [[ -n "${checksum_pkg}" ]]; then
    echo "- checking package checksum ${source##*"/"}"
    if [[ "${checksum_pkg}" != "${checksum%%" "*}" ]]; then
      echo "- error: ${source##*"/"} does not match desired package checksum, skipping"
      return
    fi
  else
    echo "- warning: missing desired package checksum, skipping validation (pkg sha256:${checksum%%" "*})"
  fi

  unzip "${source##*"/"}" "${intermediate}"

  checksum="$(sha256sum "${intermediate}")"
  if [[ -n "${checksum_bin}" ]]; then
    echo "- checking binary checksum ${intermediate}"
    if [[ "${checksum_bin}" != "${checksum%%" "*}" ]]; then
      echo "- error: ${intermediate} does not match desired binary checksum, skipping"
      return
    fi
  else
    echo "- warning: missing desired binary checksum, skipping validation (bin sha256:${checksum%%" "*})"
  fi

  install -Tm 755 "${intermediate}" "${target}"
  rm -rf "${source##*"/"}" "${intermediate%%"/"*}"

  echo "- installed ${target}"
}

main() {
  local file="${1}" pkg

  parse-requirements "${file}"

  # installing debs
  local -a debs=() npms=() others=()
  for pkg in "${packages[@]}"; do
    case "${types["${pkg}"]}" in
    deb)
      # TODO: Manage arch and distro from qualifiers
      if [[ -n "${versions["${pkg}"]:-}" ]]; then
        debs+=("${names["${pkg}"]}=${versions["${pkg}"]}")
      else
        debs+=("${names["${pkg}"]}")
      fi
      ;;
    npm)
      if [[ -n "${versions["${pkg}"]}" ]]; then
        npm+=("${namespace["${pkg}"]}/${names["${pkg}"]}@${versions["${pkg}"]}")
      else
        npm+=("${namespace["${pkg}"]}/${names["${pkg}"]}")
      fi
      ;;
    *)
      others+=("${pkg}")
      ;;
    esac
  done

  if [[ "${#debs[@]}" -ne 0 ]]; then
    echo ---
    install-from-apt "${debs[@]}"
  fi

  if [[ "${#npms[@]}" -ne 0 ]]; then
    echo ---
    for pkg in "${npms[@]}"; do
      install-from-npm "${pkg}"
    done
  fi

  if [[ "${#others[@]}" -ne 0 ]]; then
    for pkg in "${others[@]}"; do
      local ref="${types["${pkg}"]}/${namespaces["${pkg}"]:-}/${names["${pkg}"]}" version="${versions["${pkg}"]:-}"

      local target="${targets["${ref}"]:-}" source="${sources["${ref}"]:-}" intermediate="${intermediates["${ref}"]:-}"

      echo ---

      # TODO: fetch and propagate checksums from qualifiers

      if [[ -z "${version}" ]]; then
        echo "error: no version found for ${ref}, skipping..."
        continue
      fi
      if [[ -z "${target}" ]]; then
        echo "error: no target mapping found for ${ref}, skipping..."
        continue
      fi

      export version="${version#"v"}"

      target="$(envsubst <<<"${target}")"
      source="$(envsubst <<<"${source}")"
      intermediate="$(envsubst <<<"${intermediate}")"

      case "${source}" in
      "")
        echo "error: no source mapping found for ${ref}, skipping..."
        continue
        ;;
      *.tar.gz | *.tgz)
        if [[ -z "${intermediate}" ]]; then
          echo "error: no intermediate mapping found for ${ref}, skipping..."
          continue
        fi
        install-from-tar "${target}" "${source}" "${intermediate}"
        ;;
      *.zip)
        if [[ -z "${intermediate}" ]]; then
          echo "error: no intermediate mapping found for ${ref}, skipping..."
          continue
        fi
        install-from-zip "${target}" "${source}" "${intermediate}"
        ;;
      *)
        install-from-bin "${target}" "${source}"
        ;;
      esac
    done
  fi
}

main "${@}"
