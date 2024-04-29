#!/usr/bin/env bash

# This hook will create resources from manifests if they do not exist.

set -euo pipefail

declare ck8s hook root

hook="$(dirname "$(readlink -f "$0")")"
root="$(dirname "$(dirname "${hook}")")"
ck8s="${root}/bin/ck8s"

create_from_manifest() {
  local cluster
  cluster="$1"

  create_if_not_exists() {
    if ! [[ -f "${1:-}" ]]; then
      echo "error: invalid or missing file { ${1:-MISSING} }"
      exit 1
    fi

    if "${ck8s}" ops kubectl "${cluster}" get -f "$1" > /dev/null; then
      echo "note: resources already created from manifest { ${file} }"
    else
      echo "note: creating resources from manifest { ${file} }"
      "${ck8s}" ops kubectl "${cluster}" create -f "$1"
    fi
  }

  for file in "${@:2}"; do
    create_if_not_exists "${hook}/${file}"
  done
}

case "${1:-}" in
service_cluster)
  create_from_manifest sc "${@:2}"
  ;;
workload_cluster)
  create_from_manifest wc "${@:2}"
  ;;
*)
  echo "error: invalid or missing environment { ${1:-MISSING} }"
  exit 1
  ;;
esac
