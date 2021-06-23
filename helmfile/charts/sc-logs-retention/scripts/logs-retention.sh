#!/bin/bash

S3_BACKUP=${S3_BACKUP:-""}
GCS_BACKUP=${GCS_BACKUP:-""}

set -euo pipefail

: "${RETENTION_DAYS:?Missing RETENTION_DAYS}"
: "${BUCKET_NAME:?Missing BUCKET_NAME}"

if [[ ${S3_BACKUP} == "true" ]]; then
  : "${S3_REGION_ENDPOINT:?Missing S3_REGION_ENDPOINT}"
elif [[ ${GCS_BACKUP} == "true" ]]; then
  : "${GCS_KEYFILE:?Missing GCS_KEYFILE}"
fi

echo "Deleting old SC log backups (retain ${RETENTION_DAYS} days)"

if [[ ${S3_BACKUP} == "true" ]]; then
  SC_LOG_BACKUPS=$(aws s3 ls "s3://${BUCKET_NAME}/logs/" --endpoint-url="${S3_REGION_ENDPOINT}" | awk '{print $2}')

elif [[ ${GCS_BACKUP} == "true" ]]; then
  BACKUP_PREFIX="gs://${BUCKET_NAME}/logs/"

  SC_LOG_BACKUPS=$(gsutil -o "Credentials:gs_service_key_file=${GCS_KEYFILE}" ls "${BACKUP_PREFIX}" | \
    sed 's!'"${BACKUP_PREFIX}"'!!')

else
  echo "ERROR: No backup backend is enabled" >&2
  exit 1
fi

declare -a SC_LOG_BACKUPS_LATEST
declare -a SC_LOG_BACKUPS_REST
mapfile -t SC_LOG_BACKUPS_LATEST < <(echo "${SC_LOG_BACKUPS}" | tail -n "${RETENTION_DAYS}")
mapfile -t SC_LOG_BACKUPS_REST < <(echo "${SC_LOG_BACKUPS}" | head -n "-${RETENTION_DAYS}")

if [ ${#SC_LOG_BACKUPS_REST[*]} -eq 0 ]; then
  echo "No backups were found for automatic removal"
else
  echo "Listing ${RETENTION_DAYS} latest backups"
  echo "${SC_LOG_BACKUPS_LATEST[@]}"
  echo
  echo "Listing the rest"
  echo "${SC_LOG_BACKUPS_REST[@]}"
  echo
  for BACKUP in "${SC_LOG_BACKUPS_REST[@]}"; do
    if [[ ${S3_BACKUP} == "true" ]]; then
      BACKUP_URI="s3://${BUCKET_NAME}/logs/${BACKUP}"
      # As some providers have a fualty or incomplete implementation of the S3 API, a loop is needed in cases it's lacking
      echo "Deleting backup ${BACKUP_URI}"

      # Get the number of files currenctly avalible for deletion
      NR_OF_FILES=$(aws s3 ls "${BACKUP_URI}" --endpoint-url="${S3_REGION_ENDPOINT}" | wc -l)
      # As long as there are files to be deleted, keep deleting them
      while [ "$NR_OF_FILES" -gt 0 ]; do
        aws s3 rm --recursive "${BACKUP_URI}" --endpoint-url="${S3_REGION_ENDPOINT}"
        # Wait 5 seconds to see if new files have been created while the deletion was done
        sleep 5
        NR_OF_FILES=$(aws s3 ls "${BACKUP_URI}" --endpoint-url="${S3_REGION_ENDPOINT}" | wc -l)
      done

    elif [[ ${GCS_BACKUP} == "true" ]]; then
      BACKUP_URI="gs://${BUCKET_NAME}/logs/${BACKUP}"

      echo "Deleting backup ${BACKUP_URI}"
      gsutil -o "Credentials:gs_service_key_file=${GCS_KEYFILE}" rm "$BACKUP_URI"
    fi
  done
fi
