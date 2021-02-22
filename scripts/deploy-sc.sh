#!/bin/bash

set -euo pipefail

SCRIPTS_PATH="$(dirname "$(readlink -f "$0")")"
# shellcheck disable=SC1090 # Can't follow non-constant source.
source "${SCRIPTS_PATH}/../bin/common.bash"

: "${config[config_file_sc]:?Missing config}"
: "${secrets[secrets_file]:?Missing secrets}"

alertTo=$(yq r -e "${config[config_file_sc]}" 'alerts.alertTo')
if [[ "$alertTo" != "slack" && "$alertTo" != "null" && "$alertTo" != "opsgenie" ]]
then
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
helmfile -f . -e service_cluster "${helmfile_opt_flags[@]}" apply --suppress-diff

# Restore InfluxDB from backup
# Requires dropping existing databases first
restore=$(yq r -e "${config[config_file_sc]}" 'restore.cluster')
if [[ $restore != "false" ]]
then
    echo "Restoring InfluxDB" >&2
    envsubst < "${SCRIPTS_PATH}/../manifests/restore/restore-influx.yaml" | kubectl -n influxdb-prometheus apply -f -
fi

velero=$(yq r -e "${config[config_file_sc]}" 'restore.velero')
if [[ $velero == "true" ]]
then
    user_grafana=$(yq r -e "${config[config_file_sc]}" 'user.grafana.enabled')
    if [[ $user_grafana == "true" ]]
    then
        # Need to delete the user-grafana deployment and pvc created by
        # Helm before restoring it from backup.
        kubectl delete deployment -n monitoring user-grafana
        kubectl delete pvc -n monitoring user-grafana
    fi
    velero_backup_name=$(yq r -e "${config[config_file_sc]}" 'restore.veleroBackupName')
    if [[ "$velero_backup_name" != "latest" ]]
    then
        velero restore create --from-backup "$velero_backup_name" -w
    else
        velero restore create --from-schedule velero-daily-backup -w
    fi
fi
echo "Deploy sc completed!" >&2
