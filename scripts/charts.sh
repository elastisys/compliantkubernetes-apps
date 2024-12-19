#!/usr/bin/env bash

set -euo pipefail

HERE="$(readlink -f "${0}")"
ROOT="$(dirname "$(dirname "${HERE}")")"

CHARTS="${ROOT}/helmfile.d/upstream"
INDEX="${CHARTS}/index.yaml"

RETURN="0"

# strips any colour escapes if stdout isn't a tty
out() {
  if [[ -t 1 ]]; then
    echo -e "${*}"
  else
    sed -E 's/\\e\[[0-9]+m//g' <<<"${*}"
  fi
}

if [[ ! -d "${CHARTS}" ]]; then
  echo "err: ${CHARTS} is not a directory"
  exit 1
elif [[ ! -f "${INDEX}" ]]; then
  echo "err: ${INDEX} is not a file"
  exit 1
fi

run_diff() {
  chart="${1}"
  out "${chart}:"

  current_version="$(yq4 .version "${CHARTS}/${chart}/Chart.yaml" 2>/dev/null || true)"
  if [[ -z "${current_version}" ]] || [[ "${current_version}" == "null" ]]; then
    out "  state: \e[33mskipped\e[0m - missing"
    return
  fi

  requested_version="${3:-}"
  if [[ -z "${requested_version}" ]]; then
    requested_version="$(yq4 ".charts.\"${chart}\"" "${INDEX}")"
  fi

  error="$(helm show chart "${chart}" --version "${requested_version}" 2>&1 >/dev/null || true)"
  error="$(grep "Error" <<<"${error}" || true)"
  if [[ "${error}" =~ ^Error: ]]; then
    out "  state: \e[31mfailure\e[0m - ${error##Error: }"
    return
  fi

  part="${2:-}"
  case "${part}" in
  "")
    echo "error: diff: missing argument"
    usage
    ;;
  all)
    rm -rf "/tmp/charts/${chart}"
    helm pull "${chart}" --version "${requested_version}" --untar --untardir "/tmp/charts/${chart%%/*}" &>/dev/null
    if diff -r --color -U3 "${CHARTS}/${chart}" "/tmp/charts/${chart}"; then
      out "  state: \e[32mvalid\e[0m"
      RETURN="1"
    fi
    rm -rf "/tmp/charts/${chart}"
    ;;
  chart | crds | readme | values)
    if diff --color -U3 --label "current: ${chart} - ${current_version}" <(helm show "${part}" "${CHARTS}/${chart}" 2>/dev/null) --label "requested: ${chart} - ${requested_version}" <(helm show "${part}" "${chart}" --version "${requested_version}" 2>/dev/null); then
      out "  state: \e[32mvalid\e[0m"
      RETURN="1"
    fi
    ;;
  *)
    echo "error: diff: invalid argument"
    usage
    ;;
  esac
}

run_list() {
  chart="${1}"
  out "${chart}:"

  requested_version="$(yq4 ".charts.\"${chart}\"" "${INDEX}")"

  current_version="$(yq4 '.version + " - " + .appVersion' "${CHARTS}/${chart}/Chart.yaml" 2>/dev/null || true)"
  current_appversion="${current_version#* - }"
  current_version="${current_version%% - *}"

  latest_version="$(helm show chart "${chart}" 2>/dev/null | yq4 '.version + " - " + .appVersion' || true)"
  latest_appversion="${latest_version#* - }"
  latest_version="${latest_version%% - *}"

  if [[ "${requested_version}" == "${latest_version}" ]]; then
    out "  requested-version: \e[32m${requested_version}\e[0m"
  else
    out "  requested-version: \e[33m${requested_version}\e[0m"
  fi

  if [[ "${current_version}" == "" ]]; then
    out "  current-version: \e[31mmissing\e[0m"
  elif [[ "${current_version}" == "${latest_version}" ]]; then
    out "  current-version: \e[32m${current_version} - app ${current_appversion}\e[0m"
  elif [[ "${current_version}" == "${requested_version}" ]]; then
    out "  current-version: \e[33m${current_version} - app ${current_appversion}\e[0m"
  else
    out "  current-version: \e[31m${current_version} - app ${current_appversion}\e[0m"
    RETURN="1"
  fi
  if [[ "${latest_version}" == "" ]]; then
    out "  latest-version: \e[31mmissing\e[0m"
    RETURN="1"
  else
    out "  latest-version: \e[32m${latest_version} - app ${latest_appversion}\e[0m"
  fi
}

run_pull() {
  chart="${1}"
  out "${chart}:"
  requested_version="$(yq4 ".charts.\"${chart}\"" "${INDEX}")"
  out "  requested-version: \e[34m${requested_version}\e[0m"

  current_version="$(yq4 .version "${CHARTS}/${chart}/Chart.yaml" 2>/dev/null || true)"
  if [[ "${current_version}" == "${requested_version}" ]] && [[ "${2:-}" != "--force" ]]; then
    out "  state: \e[33mskipped\e[0m - up to date"
    return
  fi

  if [[ -d "${CHARTS}/tmp/${chart}" ]]; then
    rm -rf "${CHARTS}/tmp/${chart}"
  fi

  mkdir -p "${CHARTS}/tmp"

  error="$(helm pull "${chart}" --version "${requested_version}" --untar --untardir "${CHARTS}/tmp/${chart%%/*}" 2>&1 >/dev/null || true)"
  error="$(grep "Error" <<<"${error}" || true)"
  if [[ -z "${error}" ]]; then
    rm -rf "${CHARTS:?}/${chart:?}"
    mkdir -p "${CHARTS}/${chart%%/*}"
    mv "${CHARTS}/tmp/${chart}" "${CHARTS}/${chart}"
    out "  state: \e[32msuccess\e[0m"
  else
    out "  state: \e[31mfailure\e[0m - ${error##Error: }"
    RETURN="1"
  fi

  rm -rf "${CHARTS}/tmp"
}

run_verify() {
  chart="${1}"
  out "${chart}:"

  current_version="$(yq4 .version "${CHARTS}/${chart}/Chart.yaml" 2>/dev/null || true)"
  if [[ -z "${current_version}" ]] || [[ "${current_version}" == "null" ]]; then
    out "  state: \e[33mskipped\e[0m - missing"
    return
  fi

  error="$(helm show chart "${chart}" --version "${current_version}" 2>&1 >/dev/null || true)"
  error="$(grep "Error" <<<"${error}" || true)"
  if [[ "${error}" =~ ^Error: ]]; then
    out "  state: \e[31mfailure\e[0m - ${error##Error: }"
    RETURN="1"
    return
  fi

  rm -rf "/tmp/charts/${chart}"

  helm pull "${chart}" --version "${current_version}" --untar --untardir "/tmp/charts/${chart%%/*}" 2>/dev/null

  remote="$(find "/tmp/charts/${chart}" -type f -exec sha256sum {} + | awk '{print $1}' | sort | sha256sum)"
  local="$(find "${CHARTS}/${chart}" -type f -exec sha256sum {} + | awk '{print $1}' | sort | sha256sum)"

  if [[ "${remote}" == "${local}" ]]; then
    out "  state: \e[32mvalid\e[0m"
  else
    out "  state: \e[31minvalid\e[0m - invalid checksum"
    RETURN="1"
  fi

  rm -rf "/tmp/charts/${chart}"
}

usage() {
  out >&2
  out "commands: " >&2
  out "- repo add|list|update|remove" >&2
  out >&2
  out "- diff all|<chart> all|chart|crds|readme|values [version]" >&2
  out "- list all|<chart>" >&2
  out "- pull all|<chart>" >&2
  out "- verify all|<chart>" >&2
  exit 1
}

case "${1:-}" in
diff | list | pull | verify)
  case "${2:-}" in
  "")
    echo "error: ${1}: missing argument"
    usage
    ;;
  all)
    for chart in $(yq4 '.charts | keys | .[]' "${INDEX}"); do
      "run_${1}" "${chart}" "${@:3}"
    done
    ;;
  *)
    charts="$(yq4 ".charts | keys | .[] | select(match(\"${2}\$\"))" "${INDEX}")"
    if [[ -z "${charts}" ]]; then
      out "\e[31merror\e[0m: invalid chart identifier \"${2}\""
      exit 1
    fi

    for chart in ${charts}; do
      "run_${1}" "${chart}" "${@:3}"
    done
    ;;
  esac
  exit "${RETURN}"
  ;;

repo)
  case "${2:-}" in
  add)
    for repository in $(yq4 '.repositories | keys | .[]' "${INDEX}"); do
      helm repo add "${repository}" "$(yq4 ".repositories.\"${repository}\"" "${INDEX}")"
    done
    ;;
  list)
    for repository in $(yq4 '.repositories | keys | .[]' "${INDEX}"); do
      out "${repository}: $(yq4 ".repositories.\"${repository}\"" "${INDEX}")"
    done
    ;;
  update)
    for repository in $(yq4 '.repositories | keys | .[]' "${INDEX}"); do
      helm repo update "${repository}"
    done
    ;;
  remove)
    for repository in $(yq4 '.repositories | keys | .[]' "${INDEX}"); do
      helm repo remove "${repository}"
    done
    ;;
  "")
    echo "error: repo: missing argument"
    usage
    ;;
  *)
    echo "error: repo: invalid argument ${1}"
    usage
    ;;
  esac
  ;;

"")
  echo "error: missing command"
  usage
  ;;

*)
  echo "error: invalid command ${1}"
  usage
  ;;
esac
