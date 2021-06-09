#!/bin/bash

set -eu -o pipefail

# This is a very simplistic dry-run command. It runs helmfile diff.
# This at least gives the user some indication if something has changed.
# It's not to be executed on it's own but rather via `ck8s dry-run`.

# TODO: Implement a proper dry-run command which actually gives the user some
#       reassurance that the cluster will not change when deploying.

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

config_load "$1"

#
# Helmfile diff
#
if [[ $1 == "sc" ]]; then
  log_info "Running helmfile diff on the service cluster"

  "${here}/ops.bash" helmfile sc diff

elif [[ $1 == "wc" ]]; then
  log_info "Running helmfile diff on the workload cluster"

  "${here}/ops.bash" helmfile wc diff
else
  log_error "ERROR: unsupported option for dry-run. Supported options are <wc|sc>"
  exit 1
fi
