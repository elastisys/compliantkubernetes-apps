#!/bin/bash

set -euo pipefail

SCRIPTS_PATH="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${SCRIPTS_PATH}/../bin/common.bash"

: "${config[config_file_sc]:?Missing config}"
: "${secrets[secrets_file]:?Missing secrets}"

alertTo=$(yq r -e "${config[config_file_sc]}" 'alerts.alertTo')
if [[ "$alertTo" != "slack" && "$alertTo" != "null" && "$alertTo" != "opsgenie" ]]; then
    log_error "ERROR: alerts.alertTo must be set to one of slack, opsgenie or null."
    exit 1
fi

INTERACTIVE=${1:-""}

objectStoreProvider=$(yq r -e "${config[config_file_sc]}" objectStorage.type)
if [[ ${objectStoreProvider} == "s3" ]]; then
    echo "Creating fluentd secrets" >&2
    s3_access_key=$(sops_exec_file "${secrets[secrets_file]}" 'yq r -e {} objectStorage.s3.accessKey')
    s3_secret_key=$(sops_exec_file "${secrets[secrets_file]}" 'yq r -e {} objectStorage.s3.secretKey')
    kubectl create secret generic s3-credentials -n fluentd \
        --from-literal=s3_access_key="${s3_access_key}" \
        --from-literal=s3_secret_key="${s3_secret_key}" \
        --dry-run=client -o yaml | kubectl apply -f -
fi

echo "Installing helm charts" >&2
cd "${SCRIPTS_PATH}/../helmfile"
declare -a helmfile_opt_flags
[[ -n "$INTERACTIVE" ]] && helmfile_opt_flags+=("$INTERACTIVE")

if [ ${#} -eq 1 ] && [ "$1" = "sync" ]; then
    helmfile -f . -e service_cluster sync
else
    helmfile -f . -e service_cluster apply --suppress-diff
fi

echo "Deploy sc completed!" >&2

isSSOenabled=$(yq r -e "${config[config_file_sc]}" elasticsearch.sso.enabled)

if [[ ${isSSOenabled} == "true" ]]; then
../bin/ck8s ops kubectl sc delete pod -n elastic-system -l role=kibana &> /dev/null
fi