#!/bin/bash

set -euo pipefail

SCRIPTS_PATH="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${SCRIPTS_PATH}/../bin/common.bash"

config_load sc --skip-validation

: "${config[config_file_sc]:?Missing config}"
: "${secrets[secrets_file]:?Missing secrets}"

alertTo=$(yq4 '.alerts.alertTo' "${config[config_file_sc]}")
if [[ "$alertTo" != "slack" && "$alertTo" != "null" && "$alertTo" != "opsgenie" ]]; then
    log_error "ERROR: alerts.alertTo must be set to one of slack, opsgenie or null."
    exit 1
fi

echo "Installing helm charts" >&2
cd "${SCRIPTS_PATH}/../helmfile"

if [ ${#} -eq 1 ] && [ "$1" = "sync" ]; then
    helmfile -f . -e service_cluster sync "$2"
else
    helmfile -f . -e service_cluster apply "$2" --suppress-diff
fi

echo "Deploy sc completed!" >&2
