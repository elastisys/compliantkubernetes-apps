#!/usr/bin/env bash

set -euo pipefail

# Ensure CK8S_CONFIG_PATH is set
if [ -z "${CK8S_CONFIG_PATH:-}" ]; then
  echo "Error: CK8S_CONFIG_PATH environment variable is not set." >&2
  echo "Please set it to your ck8s configuration directory." >&2
  exit 1
fi

# Auto-detect STORAGE_TYPE from common-config.yaml
CONFIG_FILE="${CK8S_CONFIG_PATH}/defaults/common-config.yaml"
if [ ! -f "${CONFIG_FILE}" ]; then
  echo "Error: Configuration file not found: ${CONFIG_FILE}" >&2
  exit 1
fi

STORAGE_TYPE=$(yq '.objectStorage.type' "${CONFIG_FILE}")

# Check if STORAGE_TYPE is empty (key missing or yq failed to extract)
if [ -z "${STORAGE_TYPE}" ]; then
  echo "Error: Missing or empty '.objectStorage.type' in ${CONFIG_FILE}." >&2
  echo "This script requires '.objectStorage.type' to be set to either 's3' or 'azure'." >&2
  exit 1
fi

# Check if STORAGE_TYPE is not 's3' or 'azure'
if ! [[ "${STORAGE_TYPE}" =~ ^(s3|azure)$ ]]; then
  echo "Error: Unsupported '.objectStorage.type' ('${STORAGE_TYPE}') found in ${CONFIG_FILE}." >&2
  echo "This script currently only supports 's3' or 'azure' for Harbor restore." >&2
  exit 1
fi

SPECIFIC_BACKUP_ARG=""
AZURE_RCLONE_FIXUP_FLAG=false # Default: do not run the Azure rclone fixup job

# Parse optional arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
  --backup-id)
    if [ -n "${2:-}" ]; then
      SPECIFIC_BACKUP_ARG="$2"
      shift 2
    else
      echo "Error: --backup-id requires a value." >&2
      echo "Usage: $0 [--backup-id <backup_id_value>] [--azure-rclone-fixup]" >&2
      exit 1
    fi
    ;;
  --azure-rclone-fixup)
    AZURE_RCLONE_FIXUP_FLAG=true
    shift 1
    ;;
  *)
    echo "Error: Unknown argument: $1" >&2
    echo "Usage: $0 [--backup-id <backup_id_value>] [--azure-rclone-fixup]" >&2
    exit 1
    ;;
  esac
done

# If there are any other arguments, it's an error (this check is now part of the loop's * case)
# if [ -n "${1:-}" ]; then
#   echo "Error: Unknown arguments: $1" >&2
#   echo "Usage: $0 [--backup-id <backup_id_value>]" >&2
#   exit 1
# fi

# Optional: 1747441979 or 1747441979.tgz or backups/1747441979.tgz

# Ensure operations are performed from the compliantkubernetes-apps root directory
if [ ! -f "bin/ck8s" ]; then
  echo "Error: This script must be run from the compliantkubernetes-apps root directory."
  exit 1
fi

echo "Starting Harbor restore from ${STORAGE_TYPE}..."

# Determine the SPECIFIC_BACKUP key for the restore job
if [ -n "${SPECIFIC_BACKUP_ARG}" ]; then
  if [[ "${SPECIFIC_BACKUP_ARG}" =~ ^[0-9]+$ ]]; then
    # Purely numeric ID provided, construct the full path with .tgz extension
    export SPECIFIC_BACKUP="backups/${SPECIFIC_BACKUP_ARG}.tgz"
    echo "Interpreted numeric ID to backup path: ${SPECIFIC_BACKUP}"
  elif [[ "${SPECIFIC_BACKUP_ARG}" == backups/* && "${SPECIFIC_BACKUP_ARG}" == *.tgz ]]; then
    # Full path like backups/ID.tgz provided
    export SPECIFIC_BACKUP="${SPECIFIC_BACKUP_ARG}"
    echo "Using provided full backup path: ${SPECIFIC_BACKUP}"
  elif [[ "${SPECIFIC_BACKUP_ARG}" != */* && "${SPECIFIC_BACKUP_ARG}" == *.tgz ]]; then
    # Filename like ID.tgz provided, prepend backups/
    export SPECIFIC_BACKUP="backups/${SPECIFIC_BACKUP_ARG}"
    echo "Interpreted filename to backup path: ${SPECIFIC_BACKUP}"
  else
    echo "Error: Invalid format for specific backup argument: '${SPECIFIC_BACKUP_ARG}'." >&2
    echo "Please provide a numeric backup ID (e.g., 1747441979)," >&2
    echo "a filename with .tgz extension (e.g., 1747441979.tgz)," >&2
    echo "or a full path (e.g., backups/1747441979.tgz)." >&2
    exit 1
  fi
  echo "Using specific backup key for restore job: ${SPECIFIC_BACKUP}"
else
  export SPECIFIC_BACKUP="" # This will trigger the latest backup logic in the underlying restore script
  echo "No specific backup argument provided; the latest backup will be restored."
fi

# Common pre-restore: Scale down Harbor deployments
echo "Scaling down Harbor deployments..."
./bin/ck8s ops kubectl sc scale deployment --replicas 0 -n harbor --all

# Storage-specific setup
if [ "${STORAGE_TYPE}" == "s3" ]; then
  echo "Setting up for S3 restore..."
  S3_BUCKET=""
  S3_REGION_ENDPOINT=""
  S3_BUCKET=$(yq '.objectStorage.buckets.harbor' "${CK8S_CONFIG_PATH}/defaults/sc-config.yaml")
  S3_REGION_ENDPOINT=$(yq '.objectStorage.s3.regionEndpoint' "${CK8S_CONFIG_PATH}/common-config.yaml")
  export S3_BUCKET
  export S3_REGION_ENDPOINT
  envsubst >tmp-job.yaml <restore/harbor/restore-harbor-job.yaml
  ./bin/ck8s ops kubectl sc create configmap -n harbor restore-harbor --from-file=restore/harbor/restore-harbor.sh --dry-run=client -o yaml | ./bin/ck8s ops kubectl sc apply -f -
elif [ "${STORAGE_TYPE}" == "azure" ]; then
  echo "Setting up for Azure restore..."

  if [ "${AZURE_RCLONE_FIXUP_FLAG}" = true ]; then
    echo "Running Azure rclone fixup job..."
    S3_BUCKET=""
    AZURE_ACCOUNT=""
    AZURE_KEY=""
    S3_BUCKET=$(yq '.objectStorage.buckets.harbor' "${CK8S_CONFIG_PATH}/defaults/sc-config.yaml")
    AZURE_ACCOUNT=$(yq '.objectStorage.azure.storageAccountName' "${CK8S_CONFIG_PATH}/common-config.yaml")
    AZURE_KEY=$(sops -d --extract '["objectStorage"]["azure"]["storageAccountKey"]' "${CK8S_CONFIG_PATH}/secrets.yaml")
    export S3_BUCKET
    export AZURE_ACCOUNT
    export AZURE_KEY
    envsubst >tmp-rclone-job.yaml <restore/harbor/harbor-rclone-azure.yaml
    ./bin/ck8s ops kubectl sc apply -f tmp-rclone-job.yaml
    echo "Waiting for Rclone data move job to complete..."
    ./bin/ck8s ops kubectl sc wait --for=condition=complete job -n harbor harbor-restore-rclone-move --timeout=-1s
    echo "Cleaning up Rclone data move job artifacts..."
    ./bin/ck8s ops kubectl sc delete -f tmp-rclone-job.yaml
  else
    echo "Skipping Azure Rclone data move. Use --azure-rclone-fixup if this step is needed for your backup."
  fi

  echo "Preparing Harbor database restore for Azure..."
  envsubst >tmp-job.yaml <restore/harbor/restore-harbor-job-azure.yaml
  ./bin/ck8s ops kubectl sc create configmap -n harbor restore-harbor --from-file=restore/harbor/restore-harbor.sh --dry-run=client -o yaml | ./bin/ck8s ops kubectl sc apply -f -
else
  echo "Error: Invalid storage type '${STORAGE_TYPE}'. Must be 's3' or 'azure'."
  exit 1
fi

# Common restore steps
echo "Applying network policies and restore job..."
./bin/ck8s ops kubectl sc apply -n harbor -f restore/harbor/network-policies-harbor.yaml
./bin/ck8s ops kubectl sc apply -n harbor -f tmp-job.yaml
echo "Waiting for Harbor restore job to complete..."
./bin/ck8s ops kubectl sc wait --for=condition=complete job -n harbor restore-harbor-job --timeout=-1s

# Common post-restore: Scale up Harbor deployments
echo "Scaling up Harbor deployments..."
./bin/ck8s ops kubectl sc scale deployment --replicas 1 -n harbor --all

# Common cleanup
echo "Cleaning up restore artifacts..."
./bin/ck8s ops kubectl sc delete -n harbor -f restore/harbor/network-policies-harbor.yaml
./bin/ck8s ops kubectl sc delete -n harbor -f tmp-job.yaml
./bin/ck8s ops kubectl sc delete configmap -n harbor restore-harbor
rm -f tmp-job.yaml        # Ensure removal even if delete fails
rm -f tmp-rclone-job.yaml # Ensure removal even if delete fails

echo "Harbor restore from ${STORAGE_TYPE} completed successfully."
echo "Post-restore steps from documentation (manual intervention may be required):"
echo "- If restoring to a different domain, re-run the init job (see docs)."
echo "- If restoring between Swift and S3/Azure, manual object storage modifications may be needed (see docs)."
