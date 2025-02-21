#!/usr/bin/env bash

# Requirements installer for containers
# The goal is to make it usable as _the_ way to install requirements but we need to start somewhere.

set -euo pipefail
shopt -s extglob

declare prefix
prefix="${INSTALL_PREFIX:-"/usr/local/bin"}"

# host information
declare arch distro_name distro_version
arch="$(uname -m)"
if [[ -f /etc/os-release ]]; then
  distro_name="$(grep '^ID=' /etc/os-release)"
  distro_name="${distro_name#"ID="}"

  case "${distro_name}" in
  ubuntu)
    distro_version="$(grep '^VERSION_CODENAME=' /etc/os-release)"
    distro_version="${distro_version#"VERSION_CODENAME="}"
    ;;
  esac
else
  echo "warning, unable to determine distro"
fi

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

parse-mappings generic//kind "${prefix}/kind" "https://github.com/kubernetes-sigs/kind/releases/download/v\${version}/kind-linux-amd64"
parse-mappings generic//kubectl "${prefix}/kubectl" "https://storage.googleapis.com/kubernetes-release/release/v\${version}/bin/linux/amd64/kubectl"

parse-mappings github/getsops/sops "${prefix}/sops" "https://github.com/getsops/sops/releases/download/v\${version}/sops-v\${version}.linux.amd64"
parse-mappings github/hairyhenderson/gomplate "${prefix}/gomplate" "https://github.com/hairyhenderson/gomplate/releases/download/v\${version}/gomplate_linux-amd64"
parse-mappings github/helm/helm "${prefix}/helm" "https://get.helm.sh/helm-v\${version}-linux-amd64.tar.gz" linux-amd64/helm
parse-mappings github/helmfile/helmfile "${prefix}/helmfile" "https://github.com/helmfile/helmfile/releases/download/v\${version}/helmfile_\${version}_linux_amd64.tar.gz" helmfile
parse-mappings github/int128/kubelogin "${prefix}/kubectl-oidc_login" "https://github.com/int128/kubelogin/releases/download/v\${version}/kubelogin_linux_amd64.zip" kubelogin
parse-mappings github/mikefarah/yq "${prefix}/yq4" "https://github.com/mikefarah/yq/releases/download/v\${version}/yq_linux_amd64"
parse-mappings github/mikefarah/yq3 "${prefix}/yq" "https://github.com/mikefarah/yq/releases/download/\${version}/yq_linux_amd64"
parse-mappings github/neilpa/yajsv "${prefix}/yajsv" "https://github.com/neilpa/yajsv/releases/download/v\${version}/yajsv.linux.amd64"
parse-mappings github/open-policy-agent/opa "${prefix}/opa" "https://github.com/open-policy-agent/opa/releases/download/v\${version}/opa_linux_amd64" opa_linux_amd64
parse-mappings github/vmware-tanzu/velero "${prefix}/velero" "https://github.com/vmware-tanzu/velero/releases/download/v\${version}/velero-v\${version}-linux-amd64.tar.gz" "velero-v\${version}-linux-amd64/velero"
parse-mappings github/yannh/kubeconform "${prefix}/kubeconform" "https://github.com/yannh/kubeconform/releases/download/v\${version}/kubeconform-linux-amd64.tar.gz" kubeconform

# helm plugin install https://github.com/databus23/helm-diff --version "v${HELM_DIFF_VERSION}" >/dev/null
# helm plugin install https://github.com/jkroepke/helm-secrets --version "v${HELM_SECRETS_VERSION}" >/dev/null

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
  local purl="${1}" remainder component segment
  local -a segments

  purl="${purl##+([[:space:]])}"
  purl="${purl%%+([[:space:]])}"

  remainder="${purl}"

  # subpaths: split, discard dot and empty segments, decode, rejoin
  if [[ "${remainder}" =~ "#" ]]; then
    component="${purl##*"#"}"

    readarray -d '/' -t segments <<<"${component}"

    component=""
    for segment in "${segments[@]}"; do
      segment="${segment##+([[:space:]])}"
      segment="${segment%%+([[:space:]])}"

      if ! [[ "${segment}" =~ ^(|"."|"..")$ ]]; then
        component+="/${segment}"
      fi
    done
    component="${component#"/"}"

    subpaths["${purl}"]="$(echo -en "${component//"%"/"\\x"}")"
    remainder="${purl%"#"*}"
  fi

  # qualifiers: done on demand
  if [[ "${remainder}" =~ "?" ]]; then
    qualifiers["${purl}"]="${remainder##*"?"}"
    remainder="${remainder%"?"*}"
  fi

  # schemes: lowercase
  component="${remainder%%":"*}"
  component="${component##+([[:space:]])}"
  component="${component%%+([[:space:]])}"
  if [[ "${component,,}" != "pkg" ]]; then
    echo "invalid purl: invalid scheme"
    return
  fi
  remainder="${remainder#*":"}"

  remainder="${remainder##"/"}"
  remainder="${remainder%%"/"}"

  # types: lowercase
  component="${remainder%%"/"*}"
  component="${component##+([[:space:]])}"
  component="${component%%+([[:space:]])}"
  if [[ -z "${component}" ]]; then
    echo "invalid purl: missing type"
    return
  fi
  types["${purl}"]="${component,,}"
  remainder="${remainder#*"/"}"

  # versions: decode
  if [[ "${remainder}" =~ "@" ]]; then
    component="${remainder##*"@"}"
    component="${component##+([[:space:]])}"
    component="${component%%+([[:space:]])}"

    versions["${purl}"]="$(echo -en "${component//"%"/"\\x"}")"
    remainder="${remainder%"@"*}"
  fi

  # names: decode, normalise
  component="${remainder##*"/"}"
  component="${component##+([[:space:]])}"
  component="${component%%+([[:space:]])}"
  if [[ -z "${component}" ]]; then
    echo "invalid purl: missing name"
    return
  fi
  # TODO: normalise - not implemented yet as not types we use requires it
  names["${purl}"]="$(echo -en "${component//"%"/"\\x"}")"

  # namespaces: split, discard empty segments, decode, normalise, rejoin
  if [[ "${remainder}" =~ "/" ]]; then
    readarray -d '/' -t segments <<<"${remainder%"/"*}"

    component=""
    for segment in "${segments[@]}"; do
      segment="${segment##+([[:space:]])}"
      segment="${segment%%+([[:space:]])}"

      if [[ -n "${segment}" ]]; then
        component+="/${segment}"
      fi
    done
    component="${component#"/"}"

    # TODO: normalise - not implemented yet as not types we use requires it
    namespaces["${purl}"]="$(echo -en "${component//"%"/"\\x"}")"
  fi

  packages+=("${purl}")

  # echo "${purl} - pkg: ${types["${purl}"]} / ${namespaces["${purl}"]:-} / ${names["${purl}"]} @ ${versions["${purl}"]:-} ? ${qualifiers["${purl}"]:-} # ${subpaths["${purl}"]:-}"
}

# <package> ${qualifier[string]string}
parse-qualifier() {
  local pkg="${1}" pair key value
  local -a pairs

  # qualifiers: split, split, lowercase keys, discard empty values, decode values
  readarray -d '&' -t pairs <<<"${qualifiers["${pkg}"]:-}"
  for pair in "${pairs[@]}"; do
    [[ "${pair}" =~ "=" ]] || continue

    key="${pair%"="*}"
    key="${key##+([[:space:]])}"
    key="${key%%+([[:space:]])}"

    value="${pair#*"="}"
    value="${value##+([[:space:]])}"
    value="${value%%+([[:space:]])}"

    [[ -n "${value}" ]] || continue

    # checksum: done on demand
    qualifier["${key,,}"]="$(echo -en "${value//"%"/"\\x"}")"
  done
}

# <package> ${checksum[]string}
parse-checksum() {
  local pkg="${1}"

  # checksum: split
  readarray -d "," -t checksum <<<"${qualifier["checksum"]:-}"
  checksum=("${checksum[@]##+([[:space:]])}")
  checksum=("${checksum[@]%%+([[:space:]])}")
}

# <package>
version-from-github() {
  local pkg="${1}" namespace name

  namespace="${namespaces["${pkg}"]}"
  name="${names["${pkg}"]}"

  if ! which curl &>/dev/null; then
    echo "warning: curl not found, will not lookup github packages"
    return 1
  elif ! which jq &>/dev/null; then
    echo "warning: jq not found, will not lookup github packages"
    return 1
  fi

  local data
  data=$(curl -Ls "https://api.github.com/repos/${namespace}/${name}/releases/latest")

  local version
  version="$(jq -r '.tag_name' <<<"${data}")"

  if [[ "${version}" == nil ]]; then
    echo "warning: unable to lookup github package ${namespace}/${name}"
    return 1
  fi

  echo "- resolved github package ${namespace}/${name}@${version}"

  versions["${pkg}"]="${version}"
}

# <checksum> <target>
validate-checksum() {
  local sum="${1##*":"}" type="${1%%":"*}" target="${2}"

  case "${type}" in
  sha256)
    echo "- validating checksum ${target}"
    "${type}sum" --check - <<<"${sum} ${target}" &>/dev/null
    ;;
  *)
    echo "unsupported checksum type ${type}!" >&2
    exit 1
    ;;
  esac
}

# <packages...>
install-from-apt() {
  if ! which apt-get &>/dev/null; then
    echo "warning: apt-get not found, will not install deb packages"
    return
  fi

  apt-get update
  apt-get upgrade -y
  apt-get install -y "${@}"
  apt-get clean
  rm -rf /var/lib/apt/lists/*
}

# <packages...>
install-from-npm() {
  if ! which npm &>/dev/null; then
    echo "warning: npm not found, will not install npm packages"
    return
  fi

  local package
  for package in "${@}"; do
    npm install -g "${package}"
  done
}

# <target> <source> <intermediate> <checksum-bin> <checksum-pkg>
install-from-url() {
  local target="${1}" source="${2}" intermediate="${3}" checksum_bin="${4:-}" checksum_pkg="${5:-}"

  echo "installing ${target}"

  if [[ -e "${target}" ]] && [[ -n "${checksum_bin}" ]]; then
    if validate-checksum "${checksum_bin}" "${target}"; then
      echo "- installed ${target} matches desired binary checksum, skipping"
      return
    fi
  fi

  echo "- fetching ${target}"
  curl -#LO "${source}"

  if [[ -n "${intermediate}" ]]; then
    if [[ -n "${checksum_pkg}" ]]; then
      if ! validate-checksum "${checksum_pkg}" "${source##*"/"}"; then
        echo "- error: ${source##*"/"} does not match desired package checksum, skipping installation"
        return
      fi
    else
      echo "- warning: missing desired package checksum, skipping validation"
    fi

    case "${source}" in
    *.tar.gz | *.tgz)
      tar -xf "${source##*"/"}" "${intermediate}"
      ;;
    *.zip)
      unzip "${source##*"/"}" "${intermediate}"
      ;;
    *)
      echo "- warning: unsupported package for ${source}, skipping installation" >&2
      return
      ;;
    esac
  else
    intermediate="${source##*"/"}"
  fi

  if [[ -n "${checksum_bin}" ]]; then
    if ! validate-checksum "${checksum_bin}" "${intermediate}"; then
      echo "- error: ${intermediate} does not match desired binary checksum, skipping installation"
      return
    fi
  else
    echo "- warning: missing desired binary checksum, skipping validation"
  fi

  install -Tm 755 "${intermediate}" "${target}"
  rm -rf "${source##*"/"}" "${intermediate%%"/"*}"

  echo "- installed ${target}"
}

main() {
  local file="${1}" pkg

  parse-requirements "${file}"

  local -a debs=() npms=() others=()
  for pkg in "${packages[@]}"; do
    case "${types["${pkg}"]}" in
    deb)
      local -A qualifier
      parse-qualifier "${pkg}"

      if [[ "${namespaces["${pkg}"]}" != "${distro_name}" ]]; then
        echo "note: ${pkg} is not for ${distro_name}, skipping"
        continue
      elif [[ "${qualifier["distro"]:-}" != "${distro_version}" ]]; then
        echo "note: ${pkg} is not for ${distro_version}, skipping"
        continue
      # TODO: Generic aliasing for arch
      elif [[ "${qualifier["arch"]:-}" != "${arch/"x86_64"/"amd64"}" ]]; then
        echo "note: ${pkg} is not for ${arch}, skipping"
        continue
      fi

      if [[ -n "${versions["${pkg}"]:-}" ]]; then
        debs+=("${names["${pkg}"]}=${versions["${pkg}"]}")
      else
        debs+=("${names["${pkg}"]}")
      fi
      ;;
    npm)
      if [[ -n "${versions["${pkg}"]:-}" ]]; then
        npms+=("${namespaces["${pkg}"]}/${names["${pkg}"]}@${versions["${pkg}"]}")
      else
        npms+=("${namespaces["${pkg}"]}/${names["${pkg}"]}")
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
    install-from-npm "${npms[@]}"
  fi

  if [[ "${#others[@]}" -ne 0 ]]; then
    for pkg in "${others[@]}"; do
      local ref="${types["${pkg}"]}/${namespaces["${pkg}"]:-}/${names["${pkg}"]}" version="${versions["${pkg}"]:-}"

      local target="${targets["${ref}"]:-}" source="${sources["${ref}"]:-}" intermediate="${intermediates["${ref}"]:-}"

      echo ---

      local -A qualifier
      parse-qualifier "${pkg}"
      local -a checksum
      parse-checksum "${pkg}"

      if [[ -z "${version}" ]] && [[ "${types["${pkg}"]}" == "github" ]]; then
        if version-from-github "${pkg}"; then
          version="${versions["${pkg}"]:-}"
        fi
      fi

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

      if [[ -z "${source}" ]]; then
        echo "error: no source mapping found for ${ref}, skipping..."
        continue
      fi

      install-from-url "${target}" "${source}" "${intermediate:-}" "${checksum[0]:-}" "${checksum[1]:-}"
    done
  fi
}

main "${@}"
