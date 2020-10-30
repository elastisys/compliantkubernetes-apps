#!/bin/bash

set -euo pipefail

: "${RETENTION_DAYS:?Missing RETENTION_DAYS}"

echo "Deleting old SC log backups (retain ${RETENTION_DAYS} days)"
SC_LOG_BACKUPS=$(aws s3 ls "s3://${S3_BUCKET}/logs/" --endpoint-url="${S3_REGION_ENDPOINT}" | awk '{print $2}')
SC_LOG_BACKUPS_LATEST=$(echo "${SC_LOG_BACKUPS}" | tail -n "${RETENTION_DAYS}")
SC_LOG_BACKUPS_REST=$(echo "${SC_LOG_BACKUPS}" | head -n "-${RETENTION_DAYS}")
echo "Listing ${RETENTION_DAYS} latest backups"
echo "${SC_LOG_BACKUPS_LATEST}"
echo
echo "Listing the rest"
echo "${SC_LOG_BACKUPS_REST}"
echo
if [ -z "${SC_LOG_BACKUPS_REST}" ]; then
    echo "No backups were found for automatic removal"
else
    for BACKUP in "${SC_LOG_BACKUPS_REST[@]}"; do
        echo "Deleting backup s3://${S3_BUCKET}/logs/${BACKUP}"
        aws s3 rm --recursive "s3://${S3_BUCKET}/logs/${BACKUP}" --endpoint-url="${S3_REGION_ENDPOINT}"
    done
fi
