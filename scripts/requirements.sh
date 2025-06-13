#!/usr/bin/env bash

# Requirements installer for containers
# The goal is to make it usable as _the_ way to install requirements but we need to start somewhere.

set -euo pipefail
shopt -s extglob

note() {
  echo "note: ${*}" >&2
}
error() {
  echo "error: ${*}" >&2
}
fatal() {
  echo "fatal: ${*}" >&2
  exit 1
}
trace() {
  [[ -z "${TRACE:+true}" ]] || echo "trace ${FUNCNAME[1]}: ${*}" >&2
}
usage() {
  echo -n "usage:
  ${0} <action> <source> <requirements>
  ---
  ${0} install latest <requirements> - install the requirements using the latest versions, not verifying checksums
  ${0} update latest <requirements>  - update the requirements using the latest versions, removing checksums
  ---
  ${0} install pin <requirements> - install the requirements using the pinned versions, verifying checksums
  ${0} update pin <requirements>  - update the requirements using the pinned versions, adding checksums
  ${0} verify pin <requirements>  - verify the requirements using the pinned versions
  "
}

# install prefix, default to system installation
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

export subpaths

# others mappings
declare -A targets       # path to the binary
declare -A sources       # url to the package
declare -A intermediates # path in the package to the binary (optional if the package is the binary)

# <package> <target> <source> [intermediate]
parse-mappings() {
  local package="${1}" target="${2}" source="${3}" intermediate="${4:-}"

  targets["${package}"]="${target}"
  sources["${package}"]="${source}"
  intermediates["${package}"]="${intermediate}"
}

percent-encode() {
  local string="${1}" length="${#1}" output="" mark=0

  for ((mark = 0; mark < length; mark++)); do
    if [[ "${string:"${mark}":1}" =~ [-_.~a-zA-Z0-9] ]]; then
      output+="${string:"${mark}":1}"
    else
      output+="$(printf "%%%02x" "'${string:"${mark}":1}")"
    fi
  done

  echo -n "${output}"
}

parse-mappings generic//kind "${prefix}/kind" "https://github.com/kubernetes-sigs/kind/releases/download/v\${version}/kind-linux-amd64"
parse-mappings generic//kubectl "${prefix}/kubectl" "https://dl.k8s.io/v\${version}/kubernetes-client-linux-amd64.tar.gz" kubernetes/client/bin/kubectl

parse-mappings github/getsops/sops "${prefix}/sops" "https://github.com/getsops/sops/releases/download/v\${version}/sops-v\${version}.linux.amd64"
parse-mappings github/hairyhenderson/gomplate "${prefix}/gomplate" "https://github.com/hairyhenderson/gomplate/releases/download/v\${version}/gomplate_linux-amd64"
parse-mappings github/helm/helm "${prefix}/helm" "https://get.helm.sh/helm-v\${version}-linux-amd64.tar.gz" linux-amd64/helm
parse-mappings github/helmfile/helmfile "${prefix}/helmfile" "https://github.com/helmfile/helmfile/releases/download/v\${version}/helmfile_\${version}_linux_amd64.tar.gz" helmfile
parse-mappings github/int128/kubelogin "${prefix}/kubectl-oidc_login" "https://github.com/int128/kubelogin/releases/download/v\${version}/kubelogin_linux_amd64.zip" kubelogin
parse-mappings github/mikefarah/yq "${prefix}/yq" "https://github.com/mikefarah/yq/releases/download/v\${version}/yq_linux_amd64"
parse-mappings github/neilpa/yajsv "${prefix}/yajsv" "https://github.com/neilpa/yajsv/releases/download/v\${version}/yajsv.linux.amd64"
parse-mappings github/open-policy-agent/opa "${prefix}/opa" "https://github.com/open-policy-agent/opa/releases/download/v\${version}/opa_linux_amd64" opa_linux_amd64
parse-mappings github/vmware-tanzu/velero "${prefix}/velero" "https://github.com/vmware-tanzu/velero/releases/download/v\${version}/velero-v\${version}-linux-amd64.tar.gz" "velero-v\${version}-linux-amd64/velero"
parse-mappings github/yannh/kubeconform "${prefix}/kubeconform" "https://github.com/yannh/kubeconform/releases/download/v\${version}/kubeconform-linux-amd64.tar.gz" kubeconform

# helm plugin install https://github.com/databus23/helm-diff --version "v${HELM_DIFF_VERSION}" >/dev/null
# helm plugin install https://github.com/jkroepke/helm-secrets --version "v${HELM_SECRETS_VERSION}" >/dev/null

# parse a requirements file with purls
#
# input:
# - <file>
# output:
# - ${packages[]string}
# - ${types[string]string}
# - ${namespaces[string]string}
# - ${names[string]string}
# - ${versions[string]string}
# - ${qualifiers[string]string}
# - ${subpaths[string]string}
parse.requirements() {
  local file="${1:-}"

  [[ -f "${file}" ]] || fatal "invalid or missing requirements, $(usage)"

  local -a rows
  readarray -t rows <"${file}"

  local row
  for row in "${rows[@]}"; do
    parse.package "${row}"
  done
}

# parse a purl
#
# input:
# - <purl>
# output:
# - ${packages[]<purl>}
# - ${types[<purl>]string}
# - ${namespaces[<purl>]string}
# - ${names[<purl>]string}
# - ${versions[<purl>]string}
# - ${qualifiers[<purl>]string}
# - ${subpaths[<purl>]string}
parse.package() {
  local purl="${1}" remainder component segment
  local -a segments

  purl="${purl##+([[:space:]])}"
  purl="${purl%%+([[:space:]])}"

  trace "parsing ${purl}"

  remainder="${purl}"

  # subpaths: split, discard dot and empty segments, decode, rejoin
  if [[ "${remainder}" =~ "#" ]]; then
    component="${remainder##*"#"}"
    component="${component##+([[:space:]])}"
    component="${component%%+([[:space:]])}"

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
    remainder="${remainder%"#"*}"
  fi

  # qualifiers: done on demand
  if [[ "${remainder}" =~ "?" ]]; then
    component="${remainder##*"?"}"
    component="${component##+([[:space:]])}"
    component="${component%%+([[:space:]])}"

    qualifiers["${purl}"]="${component}"
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
}

# parse a purl's qualifiers
#
# input:
# - <purl>
# - ${qualifiers[<purl>]string}
# output:
# - ${qualifier[string]string}
parse.qualifier() {
  local purl="${1}" pair key value
  local -a pairs

  # qualifiers: split, split, lowercase keys, discard empty values, decode values
  readarray -d '&' -t pairs <<<"${qualifiers["${purl}"]:-}"
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

# parse a purl's checksum
#
# input:
# - ${qualifier[string]string}
# output:
# - ${checksum[]string}
parse.checksum() {
  # checksum: split
  readarray -d "," -t checksum <<<"${qualifier["checksum"]:-}"
  checksum=("${checksum[@]##+([[:space:]])}")
  checksum=("${checksum[@]%%+([[:space:]])}")
}

# filters purls based on namespaces
#
# input:
# - <namespace>
# - stdin <purls...>
# output:
# - stdout <purls...>
filter.namespace() {
  local namespace="${1:-}"

  local -a filter_packages
  readarray -t filter_packages -

  local package
  for package in "${filter_packages[@]}"; do
    if [[ "${namespace}" != "${namespaces["${package}"]}" ]]; then
      trace "- filter out ${package} due to namespace ${namespace}"
    fi
    echo "${package}"
  done
}

# filters purls based on qualifiers
#
# note: only filtered if the qualifier exists and doesn't match on the purl
#
# input:
# - <qualifiers...>
# - stdin <purls...>
# output:
# - stdout <purls...>
filter.qualifiers() {
  local -a filter_packages
  readarray -t filter_packages -

  local package
  for package in "${filter_packages[@]}"; do
    local -A qualifier=()
    parse.qualifier "${package}"

    local arg
    for arg in "${@}"; do
      local -a pair
      readarray -d '=' pair <<<"${arg}"

      if ! [[ "${qualifier["${pair[0]}"]:-"${pair[1]}"}" == "${pair[1]}" ]]; then
        trace "- filter out ${package} due to qualifier ${arg}"
        continue 2
      fi
    done

    echo "${package}"
  done
}

# build a requirements file with purls
#
# input:
# - <file>
# - ${packages[]string}
# - ${types[string]string}
# - ${namespaces[string]string}
# - ${names[string]string}
# - ${versions[string]string}
# - ${qualifiers[string]string}
# - ${subpaths[string]string}
# output:
# - [file]
build.requirements() {
  local file="${1:-}"

  if [[ -n "${file}" ]]; then
    touch "${file}.next"
  fi

  local pkg
  for pkg in "${packages[@]}"; do
    if [[ -n "${file}" ]]; then
      build.package "${pkg}" >>"${file}.next"
    else
      build.package "${pkg}"
    fi
  done

  if [[ -n "${file}" ]]; then
    mv "${file}.next" "${file}"
  fi
}

# build a purl
#
# input:
# - <purl>
# - ${packages[]<purl>}
# - ${types[<purl>]string}
# - ${namespaces[<purl>]string}
# - ${names[<purl>]string}
# - ${versions[<purl>]string}
# - ${qualifiers[<purl>]string}
# - ${subpaths[<purl>]string}
# output:
# - <purl>
build.package() {
  local purl="${1}" output="pkg:" segment pair key value
  local -A qualifier
  local -a segments

  purl="${purl##+([[:space:]])}"
  purl="${purl%%+([[:space:]])}"

  # type: lowercase
  output+="${types["${purl}"],,}"

  # namespace: split, encode, join
  if [[ -n "${namespaces["${purl}"]:-}" ]]; then
    readarray -d '/' -t segments <<<"${namespaces["${purl}"]}"

    for segment in "${segments[@]}"; do
      segment="${segment##+([[:space:]])}"
      segment="${segment%%+([[:space:]])}"

      output+="/$(percent-encode "${segment}")"
    done
  fi

  # name: encode
  output+="/$(percent-encode "${names["${purl}"]}")"

  # version: encode
  if [[ -n "${versions["${purl}"]:-}" ]]; then
    output+="@$(percent-encode "${versions["${purl}"]}")"
  fi

  # qualifiers: split, encode, join
  if [[ -n "${qualifiers["${purl}"]:-}" ]]; then
    parse.qualifier "${purl}"
    output+="?"
    for key in $(tr ' ' '\n' <<<"${!qualifier[@]}" | sort); do
      [[ -n "${qualifier["${key}"]}" ]] || continue

      output+="${key}=$(percent-encode "${qualifier["${key}"]}")&"
    done
    output="${output%"&"}"
  fi

  # TODO: Subpaths

  echo "${output}"
}

# build a purl's qualifier
#
# input:
# - <purl>
# - ${qualifier[string]string}
# output:
# - ${qualifiers[<purl>]string}
build.qualifier() {
  local purl="${1}" output="" key

  if [[ -z "${qualifier[*]:-}" ]]; then
    qualifiers["${purl}"]=""
    return 0
  fi

  for key in $(tr ' ' '\n' <<<"${!qualifier[@]}" | sort); do
    [[ -n "${qualifier["${key}"]}" ]] || continue

    output+="${key}=$(percent-encode "${qualifier["${key}"]}")&"
  done

  if [[ -z "${output}" ]]; then
    qualifiers["${purl}"]=""
    return 0
  fi

  qualifiers["${purl}"]="${output%"&"}"
}

set.latest() {
  local package="${1}" ref type namespace name version current_version latest_version="${2}"
  package.resolve "${package}"

  current_version="${version}"

  if [[ "${current_version}" != "${latest_version}" ]]; then
    note "${ref}: found newer version: ${current_version} -> ${latest_version}"
    # update version
    versions["${package}"]="${latest_version}"
    # clear checksum
    local -A qualifier
    parse.qualifier "${package}"
    qualifier["checksum"]=""
    build.qualifier "${package}"
  else
    note "${ref}: found matching version: ${latest_version}"
  fi
}

# track if database needs to be updated for deb packages
declare deb_metadata_update="${DEB_SKIP_METADATA_UPDATE:-"false"}"
# update database for deb packages once
deb.update() {
  if [[ "${deb_metadata_update}" == "false" ]]; then
    note "updating deb metadata"
    sudo apt-get update >/dev/null

    deb_metadata_update="true"
  fi
}

# resolve and record deb package latest versions
#
# input:
# - <purls>...
latest.deb() {
  if ! command -v apt-cache &>/dev/null; then
    note "apt-cache not available, skipping running latest on deb packages"
    return
  elif ! command -v apt-get &>/dev/null; then
    note "apt-get not available, skipping running latest on deb packages"
    return
  fi

  deb.update

  local package
  for package in $(tr ' ' '\n' <<<"${@}" | filter.namespace "${distro_name}" | filter.qualifiers "arch=${arch/"x86_64"/"amd64"}" "distro=${distro_version}"); do
    local ref type namespace name version
    package.resolve "${package}"

    version="$(apt-cache policy "${name}" | grep "Candidate:")"
    version="${version##+([[:space:]])Candidate:[[:space:]]}"

    set.latest "${package}" "${version}"
  done
}

# resolve and install recorded deb packages
#
# input:
# - <purls>...
install.deb() {
  if ! command -v apt-cache &>/dev/null; then
    note "apt-cache not available, skipping running latest on deb packages"
    return
  elif ! command -v apt-get &>/dev/null; then
    note "apt-get not available, skipping running latest on deb packages"
    return
  fi

  deb.update

  local -a debs=()

  local package
  for package in $(tr ' ' '\n' <<<"${@}" | filter.namespace "${distro_name}" | filter.qualifiers "arch=${arch/"x86_64"/"amd64"}" "distro=${distro_version}"); do
    local ref type namespace name version current_version target_version target_checksum
    package.resolve "${package}"

    current_version="$(apt-cache policy "${name}" | grep "Installed:")"
    current_version="${current_version##+([[:space:]])Installed:[[:space:]]}"

    target_version="${version}"

    local -A qualifier
    parse.qualifier "${package}"
    local -a checksum
    parse.checksum

    if [[ "${current_version}" == "${target_version}" ]]; then
      note "${ref}: found matching version ${version}, skipping"
      continue
    fi

    if [[ -n "${target_version}" ]]; then
      target_checksum="$(apt-cache show "${name}=${target_version}" | grep "SHA256:")"
      target_checksum="${target_checksum##+([[:space:]])SHA256:[[:space:]]}"
      target_checksum="${target_checksum,,}"

      # TODO: Make checksums required or optional depending on invocation
      if [[ -z "${checksum[0]:-}" ]]; then
        error "${ref}: missing checksum, continuing"
      elif [[ "${checksum[0]}" != "${target_checksum}" ]]; then
        error "${ref}: mismatching checksum, skipping"
        continue
      fi

      debs+=("${name}=${target_version}")
    else
      error "${ref}: missing version, continuing"
      debs+=("${name}")
    fi
    note "- installing package ${ref}"
  done

  if [[ -n "${debs[*]}" ]]; then
    sudo apt-get install -y "${debs[@]}" >/dev/null
  fi
}

# resolve and pin recorded deb packages checksums
#
# input:
# - <purls>...
pin.deb() {
  if ! command -v apt-cache &>/dev/null; then
    note "apt-cache not available, skipping running latest on deb packages"
    return
  fi

  local package
  for package in $(tr ' ' '\n' <<<"${@}" | filter.namespace "${distro_name}" | filter.qualifiers "arch=${arch/"x86_64"/"amd64"}" "distro=${distro_version}"); do
    local namespace="${namespaces["${package}"]:-}" name="${names["${package}"]:-}" version="${versions["${package}"]:-}"
    local ref="deb/${namespace}/${name}"

    local current_version
    current_version="$(apt-cache policy "${name}" | grep "Installed:")"
    current_version="${version##+([[:space:]])Installed:[[:space:]]}"

    if [[ "${current_version}" == "(none)" ]]; then
      error "${ref}: missing package, skipping"
      continue
    elif [[ "${current_version}" != "${version}" ]]; then
      error "${ref}: mismatching version, skipping"
      continue
    fi

    local current_checksum
    current_checksum="$(apt-cache show "${name}=${version}" | grep "SHA256:")"
    current_checksum="${current_checksum##+([[:space:]])SHA256:[[:space:]]}"
    current_checksum="${current_checksum,,}"

    local -A qualifier
    parse.qualifier "${package}"
    qualifier["checksum"]="${current_checksum}"
    build.qualifier "${package}"
  done
}

# resolve and verify recorded deb packages checksums
#
# input:
# - <purls>...
verify.deb() {
  if ! command -v apt-cache &>/dev/null; then
    note "apt-cache not available, skipping running latest on deb packages"
    return
  fi

  local package
  for package in $(tr ' ' '\n' <<<"${@}" | filter.namespace "${distro_name}" | filter.qualifiers "arch=${arch/"x86_64"/"amd64"}" "distro=${distro_version}"); do
    local -A qualifier
    parse.qualifier "${package}"
    local -a checksum
    parse.checksum

    if [[ -z "${checksum[0]:-}" ]]; then
      error "missing checksum on ${package}"
      continue
    fi

    local version
    version="$(apt-cache policy "${names["${package}"]}" | grep "Installed:")"
    version="${version##+([[:space:]])Installed:[[:space:]]}"

    if [[ "${version}" == "(none)" ]]; then
      error "missing package ${package}"
      continue
    elif [[ "${version}" != "${versions["${package}"]:-}" ]]; then
      error "mismatching version on ${package}"
      continue
    fi

    local target
    target="$(apt-cache show "${names["${package}"]}=${version}" | grep "SHA256:")"
    target="${target##+([[:space:]])SHA256:[[:space:]]}"
    target="${target,,}"

    if [[ "${checksum[0]}" != "${target}" ]]; then
      error "mismatching checksum on ${package}"
    fi
  done
}

# see mapping.install
install.generic() {
  mapping.install "${@}"
}

# see mapping.pin
pin.generic() {
  mapping.pin "${@}"
}

# see mapping.verify
verify.generic() {
  mapping.verify "${@}"
}

# resolve and record github packages latest versions
#
# input:
# - <purls>...
latest.github() {
  if ! command -v curl &>/dev/null; then
    note "curl not available, skipping running latest on github packages"
    return
  elif ! command -v jq &>/dev/null; then
    note "jq not available, skipping running latest on github packages"
    return
  fi

  local package
  for package in $(tr ' ' '\n' <<<"${@}"); do
    local ref type namespace name version response
    package.resolve "${package}"

    response=$(curl -Ls "https://api.github.com/repos/${namespace}/${name}/releases/latest")
    version="$(jq -r '.tag_name' <<<"${response}")"

    set.latest "${package}" "${version}"
  done
}

# see mapping.install
install.github() {
  mapping.install "${@}"
}

# see mapping.pin
pin.github() {
  mapping.pin "${@}"
}

# see mapping.verify
verify.github() {
  mapping.verify "${@}"
}

# resolve packages for purls
#
# input:
# - <purl>
# - ${types[<purl>]string}
# - ${namespaces[<purl>]string}
# - ${names[<purl>]string}
# - ${versions[<purl>]string}
# - ${qualifiers[<purl>]string}
# - ${subpaths[<purl>]string}
# output:
# - ${ref} - type/namespace/name
# - ${type}
# - ${namespace}
# - ${name}
# - ${version}
package.resolve() {
  local purl="${1:-}"

  type="${types["${package}"]:-}"
  namespace="${namespaces["${package}"]:-}"
  name="${names["${package}"]:-}"
  version="${versions["${package}"]:-}"

  ref="${type}/${namespace}/${name}"
}

# resolve mappings for refs
#
# input:
# - <ref>
# - <version>
# output:
# - ${target}
# - ${source}
# - ${intermediate}
mapping.resolve() {
  local ref="${1:-}" version="${2:-}"

  version="${version##v}"
  export version

  target="$(envsubst <<<"${targets["${ref}"]:-}")"
  source="$(envsubst <<<"${sources["${ref}"]:-}")"
  intermediate="$(envsubst <<<"${intermediates["${ref}"]:-}")"
}

# resolve and install recorded packages using mappings
#
# note: only supports bare binaries, tar.gz, tgz, and zip packages
#
# input:
# - <purls>...
mapping.install() {
  local package
  for package in $(tr ' ' '\n' <<<"${@}"); do
    local ref type namespace name version
    package.resolve "${package}"

    if [[ -z "${version}" ]]; then
      error "${ref}: missing version, skipping"
      continue
    fi

    local target source intermediate
    mapping.resolve "${ref}" "${version}"

    if [[ -z "${target}" ]]; then
      error "${ref}: missing target mapping, skipping"
      continue
    elif [[ -z "${source}" ]]; then
      error "${ref}: missing source mapping, skipping"
      continue
    fi

    local -A qualifier
    parse.qualifier "${package}"
    local -a checksum=()
    parse.checksum

    # TODO: Make checksums required or optional depending on invocation
    if [[ -z "${checksum[0]:-}" ]]; then
      error "${ref}: missing binary checksum, continuing"
    elif [[ -x "${target}" ]] && checksum.verify "${checksum[0]}" "${target}"; then
      note "${ref}: matching binary checksum, skipping"
      continue
    fi

    note "- fetching package ${ref}"
    curl -sLO "${source}"

    if [[ -n "${intermediate}" ]]; then
      if [[ -z "${checksum[1]:-}" ]]; then
        # TODO: Make checksums required or optional depending on invocation
        error "${ref}: missing package checksum, continuing"
      elif ! checksum.verify "${checksum[1]}" "${source##*"/"}"; then
        error "${ref}: mismatching package checksum, skipping"
        return 0
      fi

      note "- extracting package ${ref}"
      case "${source}" in
      *.tar.gz | *.tgz)
        tar -xf "${source##*"/"}" "${intermediate}"
        ;;
      *.zip)
        unzip "${source##*"/"}" "${intermediate}"
        ;;
      *)
        error "${ref}: unsupported package, skipping"
        rm "${source##*"/"}"
        continue
        ;;
      esac
      rm "${source##*"/"}"
    else
      intermediate="${source##*"/"}"
    fi

    # TODO: Make checksums required or optional depending on invocation
    if [[ -z "${checksum[0]:-}" ]]; then
      error "${ref}: missing binary checksum, continuing"
    elif ! checksum.verify "${checksum[0]}" "${intermediate}"; then
      error "${ref}: mismatching binary checksum, skipping"
      rm -r "${intermediate%%"/"*}"
      continue
    fi

    note "- installing package ${ref}"
    if ! [[ -d "$(dirname "${target}")" ]]; then
      error "${ref}: target is not a directory, unable to install, skipping"
    elif ! [[ -w "$(dirname "${target}")" ]]; then
      # system install
      sudo install -Tm 755 "${intermediate}" "${target}"
      note "${ref}: system install ${target}"
    else
      # user install
      install -Tm 755 "${intermediate}" "${target}"
      note "${ref}: user install ${target}"
    fi
    rm -r "${intermediate%%"/"*}"
  done
}

# resolve and pin recorded packages checksums using mappings
#
# input:
# - <purls>...
mapping.pin() {
  local package
  for package in $(tr ' ' '\n' <<<"${@}"); do
    local current_binary_checksum target_binary_checksum target_package_checksum

    local ref type namespace name version
    package.resolve "${package}"

    if [[ -z "${version}" ]]; then
      error "${ref}: missing version, skipping"
      continue
    fi

    local target source intermediate
    mapping.resolve "${ref}" "${version}"

    if [[ -z "${target}" ]]; then
      error "${ref}: missing target mapping, skipping"
      continue
    elif [[ -z "${source}" ]]; then
      error "${ref}: missing source mapping, skipping"
      continue
    fi

    local -A qualifier
    parse.qualifier "${package}"
    local -a checksum
    parse.checksum

    if ! [[ -x "${target}" ]]; then
      error "${ref}: missing package, skipping"
      continue
    fi

    current_binary_checksum="$(sha256sum "${target}")"
    current_binary_checksum="${current_binary_checksum%%" "*}"

    note "- fetching package ${ref}"
    curl -sLO "${source}"

    if [[ -n "${intermediate}" ]]; then
      target_package_checksum="$(sha256sum "${source##*"/"}")"
      target_package_checksum="${target_package_checksum%%" "*}"

      note "- extracting package ${ref}"
      case "${source}" in
      *.tar.gz | *.tgz)
        tar -xf "${source##*"/"}" "${intermediate}"
        ;;
      *.zip)
        unzip "${source##*"/"}" "${intermediate}"
        ;;
      *)
        error "${ref}: unsupported package, skipping"
        rm "${source##*"/"}"
        continue
        ;;
      esac
      rm "${source##*"/"}"
    else
      intermediate="${source##*"/"}"
    fi

    if ! checksum.verify "sha256:${current_binary_checksum}" "${intermediate}"; then
      error "${ref}: mismatching binary checksum, skipping"
      rm -r "${intermediate%%"/"*}"
      continue
    fi

    target_binary_checksum="$(sha256sum "${intermediate}")"
    target_binary_checksum="${target_binary_checksum%%" "*}"

    note "- pining package ${ref}"
    local -A qualifier
    parse.qualifier "${package}"
    if [[ -n "${target_package_checksum:-}" ]]; then
      qualifier["checksum"]="sha256:${target_binary_checksum},sha256:${target_package_checksum}"
    else
      qualifier["checksum"]="sha256:${target_binary_checksum}"
    fi
    build.qualifier "${package}"

    rm -r "${intermediate%%"/"*}"
  done
}

# resolve and verify recorded packages checksums using mappings
#
# input:
# - <purls>...
mapping.verify() {
  local package
  for package in $(tr ' ' '\n' <<<"${@}"); do
    local type="${types["${package}"]:-}" namespace="${namespaces["${package}"]:-}" name="${names["${package}"]:-}"
    local ref="${type}/${namespace}/${name}"

    local -A qualifier
    parse.qualifier "${package}"
    local -a checksum
    parse.checksum

    if [[ -z "${checksum[0]:-}" ]]; then
      error "${ref}: missing checksum"
      continue
    fi

    local target="${targets["${ref}"]:-}"
    target="$(envsubst <<<"${target}")"

    if [[ -z "${target}" ]]; then
      error "${ref}: missing target mapping"
      continue
    elif ! [[ -x "${target}" ]]; then
      error "${ref}: missing package"
      continue
    elif ! checksum.verify "${checksum[0]}" "${target}"; then
      error "${ref}: mismatching checksum"
    fi
  done
}

# verify checksum against the target
#
# note: currently only supports sha256, although more can be added
#
# input:
# - <checksum>
# - <target>
# output:
# - return code
checksum.verify() {
  local sum="${1##*":"}" type="${1%%":"*}" target="${2}"

  case "${type}" in
  sha256)
    trace "validating checksum ${target}"
    "${type}sum" --check - <<<"${sum} ${target}" >/dev/null
    ;;
  *)
    error "unsupported checksum type ${type}!" >&2
    return 1
    ;;
  esac
}

# dispatch actions on different package types
# note: if a type does not have a handler for a specific action it will be skipped
dispatch() {
  local dispatch_action="${1:-}"

  trace "dispatch ${dispatch_action}"

  local -a dispatch_types
  readarray -t dispatch_types <<<"$(tr ' ' '\n' <<<"${types[@]}" | sort -u)"

  echo "---"
  local dispatch_type
  for dispatch_type in "${dispatch_types[@]}"; do
    if ! declare -F "${dispatch_action}.${dispatch_type}" &>/dev/null; then
      note "no implementation to dispatch ${dispatch_action} for ${dispatch_type}, skipping"
      echo "---"
      continue
    fi

    local -a dispatch_packages=()

    local package
    for package in "${packages[@]}"; do
      if [[ "${dispatch_type}" == "${types["${package}"]}" ]]; then
        dispatch_packages+=("${package}")
      fi
    done

    trace "dispatch ${dispatch_action} for ${dispatch_type}"
    "${dispatch_action}.${dispatch_type}" "${dispatch_packages[@]}"
    echo "---"
  done
}

# main install command
main.install() {
  case "${1:-}" in
  latest)
    parse.requirements "${@:2}"
    dispatch latest
    dispatch install
    ;;
  pin)
    parse.requirements "${@:2}"
    dispatch install
    ;;
  *)
    fatal "invalid or missing source, $(usage)"
    ;;
  esac
}

# main update command
main.update() {
  case "${1:-}" in
  latest)
    parse.requirements "${@:2}"
    dispatch latest
    build.requirements "${@:2}"
    ;;
  pin)
    parse.requirements "${@:2}"
    dispatch pin
    build.requirements "${@:2}"
    ;;
  *)
    fatal "invalid or missing source, $(usage)"
    ;;
  esac
}

# main verify command
main.verify() {
  case "${1:-}" in
  pin)
    parse.requirements "${@:2}"
    dispatch verify
    ;;
  *)
    fatal "invalid or missing source, $(usage)"
    ;;
  esac
}

# main function
main() {
  case "${1:-}" in
  cat)
    parse.requirements "${@:2}"
    build.requirements
    ;;
  install | update | verify)
    "main.${1}" "${@:2}"
    ;;
  *)
    fatal "invalid or missing action, $(usage)"
    ;;
  esac
}

main "${@}"
