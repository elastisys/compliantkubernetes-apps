#!/bin/bash
set -euo pipefail
SCRIPTS_PATH="$(dirname "$(readlink -f "$0")")"
: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"
# shellcheck disable=SC1090
source "${SCRIPTS_PATH}/../../bin/common.bash"

sops_exec_env "${CK8S_CONFIG_PATH}/secrets.env" "${SCRIPTS_PATH}/migrate-secrets-to-yaml.bash"
