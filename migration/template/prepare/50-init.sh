#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

case "${CK8S_CLUSTER}" in
  both|sc|wc)
    "${ROOT}/bin/ck8s" init "${CK8S_CLUSTER}"
    ;;
  *)
    log_fatal "usage: 50-init.sh <wc|sc|both>"
    ;;
esac
