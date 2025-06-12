#!/usr/bin/env bash
set -euo pipefail

here="$(readlink -f "$(dirname "${0}")")"

# shellcheck source=bin/common.bash
source "${here}/common.bash"

usage() {
  echo "Usage: $(basename "$0") [--backup-id <backup_id_value>] [--azure-rclone-fixup]" >&2
  echo "" >&2
  echo "Restores Harbor from a backup using the detected storage type." >&2
  echo "" >&2
  echo "Options:" >&2
  echo "  --backup-id <value>      Restore from a specific backup ID" >&2
  echo "  --azure-rclone-fixup     Run Azure rclone fixup job for Azure storage" >&2
  exit 1
}

declare SPECIFIC_BACKUP_ARG=""
declare AZURE_RCLONE_FIXUP_FLAG=false # Default: do not run the Azure rclone fixup job

while [[ $# -gt 0 ]]; do
  case "$1" in
  --backup-id)
    if [ -n "${2:-}" ]; then
      SPECIFIC_BACKUP_ARG="$2"
      shift 2
    else
      log_fatal "--backup-id requires a value"
    fi
    ;;
  --azure-rclone-fixup)
    AZURE_RCLONE_FIXUP_FLAG=true
    shift 1
    ;;
  --help)
    usage
    ;;
  *)
    log_fatal "Unknown argument: $1"
    ;;
  esac
done

# Create temporary files
TMP_JOB_FILE=$(mktemp)
TMP_RCLONE_JOB_FILE=$(mktemp)

# Cleanup function using common.bash append_trap
append_trap "rm -f ${TMP_JOB_FILE}" EXIT
append_trap "rm -f ${TMP_RCLONE_JOB_FILE}" EXIT

# Display warning and require confirmation
log_warning "This script will restore Harbor from a backup, which will overwrite all current Harbor data."
log_warning "This includes all images, charts, users, projects, and configurations."
ask_abort

check_tools "$@"

log_info "Loading configuration..."
config_load "sc"

# Auto-detect STORAGE_TYPE
if ! STORAGE_TYPE=$(yq --exit-status '.objectStorage.type' "${config[config_file_sc]}"); then
  log_fatal "Missing or empty '.objectStorage.type' in merged configuration. This script requires '.objectStorage.type' to be set to either 's3' or 'azure'."
fi

# Check if STORAGE_TYPE is not 's3' or 'azure'
if ! [[ "${STORAGE_TYPE}" =~ ^(s3|azure)$ ]]; then
  log_fatal "Unsupported '.objectStorage.type' ('${STORAGE_TYPE}') found in merged configuration. This script currently only supports 's3' or 'azure' for Harbor restore."
fi

# Check if Harbor is using an internal database
if ! HARBOR_DB_TYPE=$(yq --exit-status '.harbor.database.type' "${config[config_file_sc]}"); then
  log_fatal "Missing or empty '.harbor.database.type' in merged configuration."
fi

if [ "${HARBOR_DB_TYPE}" != "internal" ]; then
  log_fatal "This script only supports restoring Harbor with an internal database. Current database type is '${HARBOR_DB_TYPE}'."
fi

log_info "Starting Harbor restore from ${STORAGE_TYPE}..."

# Determine the SPECIFIC_BACKUP key for the restore job
# Optional: 1747441979 or 1747441979.tgz or backups/1747441979.tgz
if [ -n "${SPECIFIC_BACKUP_ARG:-}" ]; then
  if [[ "${SPECIFIC_BACKUP_ARG}" =~ ^[0-9]+$ ]]; then
    # Purely numeric ID provided, construct the full path with .tgz extension
    export SPECIFIC_BACKUP="backups/${SPECIFIC_BACKUP_ARG}.tgz"
    log_info "Interpreted numeric ID to backup path: ${SPECIFIC_BACKUP}"
  elif [[ "${SPECIFIC_BACKUP_ARG}" == backups/* && "${SPECIFIC_BACKUP_ARG}" == *.tgz ]]; then
    # Full path like backups/ID.tgz provided
    export SPECIFIC_BACKUP="${SPECIFIC_BACKUP_ARG}"
    log_info "Using provided full backup path: ${SPECIFIC_BACKUP}"
  elif [[ "${SPECIFIC_BACKUP_ARG}" != */* && "${SPECIFIC_BACKUP_ARG}" == *.tgz ]]; then
    # Filename like ID.tgz provided, prepend backups/
    export SPECIFIC_BACKUP="backups/${SPECIFIC_BACKUP_ARG}"
    log_info "Interpreted filename to backup path: ${SPECIFIC_BACKUP}"
  else
    log_fatal "Invalid format for specific backup argument: '${SPECIFIC_BACKUP_ARG}'. Please provide a numeric backup ID (e.g., 1747441979), a filename with .tgz extension (e.g., 1747441979.tgz), or a full path (e.g., backups/1747441979.tgz)."
  fi
  log_info "Using specific backup key for restore job: ${SPECIFIC_BACKUP}"
else
  export SPECIFIC_BACKUP="" # This will trigger the latest backup logic in the underlying restore script
  log_info "No specific backup argument provided; the latest backup will be restored."
fi

# Common pre-restore: Scale down Harbor deployments
log_info "Scaling down Harbor deployments..."
"${root_path}/bin/ck8s" ops kubectl sc scale deployment --replicas 0 -n harbor --all

# Storage-specific setup
if [ "${STORAGE_TYPE}" == "s3" ]; then
  log_info "Setting up for S3 restore..."
  S3_BUCKET=$(yq '.objectStorage.buckets.harbor' "${config[config_file_sc]}")
  S3_REGION_ENDPOINT=$(yq '.objectStorage.s3.regionEndpoint' "${config[config_file_sc]}")
  export S3_BUCKET
  export S3_REGION_ENDPOINT
  envsubst >"${TMP_JOB_FILE}" <"${root_path}/restore/harbor/restore-harbor-job.yaml"
  "${root_path}/bin/ck8s" ops kubectl sc create configmap -n harbor restore-harbor --from-file="${root_path}/restore/harbor/restore-harbor.sh" --dry-run=client -o yaml | "${root_path}/bin/ck8s" ops kubectl sc apply -f -
elif [ "${STORAGE_TYPE}" == "azure" ]; then
  log_info "Setting up for Azure restore..."
  if [ "${AZURE_RCLONE_FIXUP_FLAG}" = true ]; then
    log_info "Running Azure rclone fixup job..."
    S3_BUCKET=$(yq '.objectStorage.buckets.harbor' "${config[config_file_sc]}")
    AZURE_ACCOUNT=$(yq '.objectStorage.azure.storageAccountName' "${config[config_file_sc]}")

    # Use SOPS to extract the Azure storage account key
    AZURE_KEY=$(sops -d --extract '["objectStorage"]["azure"]["storageAccountKey"]' "${secrets[secrets_file]}")
    export S3_BUCKET
    export AZURE_ACCOUNT
    export AZURE_KEY
    envsubst >"${TMP_RCLONE_JOB_FILE}" <"${root_path}/restore/harbor/harbor-rclone-azure.yaml"
    "${root_path}/bin/ck8s" ops kubectl sc apply -f "${TMP_RCLONE_JOB_FILE}"
    log_info "Waiting for Rclone data move job to complete..."
    "${root_path}/bin/ck8s" ops kubectl sc wait --for=condition=complete job -n harbor harbor-restore-rclone-move --timeout=-1s
    log_info "Cleaning up Rclone data move job artifacts..."
    "${root_path}/bin/ck8s" ops kubectl sc delete -f "${TMP_RCLONE_JOB_FILE}"
  else
    log_info "Skipping Azure Rclone data move. Use --azure-rclone-fixup if this step is needed for your backup."
  fi
  log_info "Preparing Harbor database restore for Azure..."
  envsubst >"${TMP_JOB_FILE}" <"${root_path}/restore/harbor/restore-harbor-job-azure.yaml"
  "${root_path}/bin/ck8s" ops kubectl sc create configmap -n harbor restore-harbor --from-file="${root_path}/restore/harbor/restore-harbor.sh" --dry-run=client -o yaml | "${root_path}/bin/ck8s" ops kubectl sc apply -f -
else
  log_fatal "Invalid storage type '${STORAGE_TYPE}'. Must be 's3' or 'azure'."
fi

# Common restore steps
log_info "Applying network policies and restore job..."
"${root_path}/bin/ck8s" ops kubectl sc apply -n harbor -f "${root_path}/restore/harbor/network-policies-harbor.yaml"
"${root_path}/bin/ck8s" ops kubectl sc apply -n harbor -f "${TMP_JOB_FILE}"

log_info "Waiting for Harbor restore job to complete..."
"${root_path}/bin/ck8s" ops kubectl sc wait --for=condition=complete job -n harbor restore-harbor-job --timeout=-1s

# Common post-restore: Scale up Harbor deployments
log_info "Scaling up Harbor deployments..."
"${root_path}/bin/ck8s" ops kubectl sc scale deployment --replicas 1 -n harbor --all

# Common cleanup
log_info "Cleaning up restore artifacts..."
"${root_path}/bin/ck8s" ops kubectl sc delete -n harbor -f "${root_path}/restore/harbor/network-policies-harbor.yaml"
"${root_path}/bin/ck8s" ops kubectl sc delete -n harbor -f "${TMP_JOB_FILE}"
"${root_path}/bin/ck8s" ops kubectl sc delete configmap -n harbor restore-harbor

log_info "Harbor restore from ${STORAGE_TYPE} completed successfully."
log_info "Post-restore steps from documentation (manual intervention may be required):"
log_info "- If restoring to a different domain, re-run the init job (see docs)."
log_info "- If restoring between Swift and S3/Azure, manual object storage modifications may be needed (see docs)."
