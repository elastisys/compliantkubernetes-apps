#!/bin/bash
# Check https://compliantkubernetes.io/operator-manual/disaster-recovery/ for instructions
# Restores latest backup from S3_BUCKET. $1 can be used to specify backup
# To get a list of available backups use:
# aws s3 ls ${S3_BUCKET}"/backups" --recursive --endpoint-url=$S3_REGION_ENDPOINT
set -e

HOSTNAME=localhost
backup_dir=backups

s3_download() {
    : "${S3_BUCKET:?Missing S3_BUCKET}"
    : "${S3_REGION_ENDPOINT:?Missing S3_REGION_ENDPOINT}"
    if [[ -n "$1" ]]; then
        backup_key=$1
    else
        backup_key=$(aws s3 ls "${S3_BUCKET}/backups" \
          --recursive \
          --endpoint-url="${S3_REGION_ENDPOINT}" \
          | sort | tail -n 1 | awk '{print $4}')
    fi
    echo "Downloading backup from s3 bucket ${backup_key}" >&2
    aws s3 cp "s3://${S3_BUCKET}/${backup_key}" harbor.tgz --endpoint-url="${S3_REGION_ENDPOINT}"
}

extract_backup(){
    echo "Extracting backups">&2
    tar xvf harbor.tgz
}

wait_for_db_ready() {
    echo "Waiting for DB to be ready" >&2
    TIMEOUT=12
    while [ $TIMEOUT -gt 0 ]; do
        if pg_isready -h $HOSTNAME | grep "accepting connections"; then
                break
        fi
        TIMEOUT=$((TIMEOUT - 1))
        sleep 5
    done
    if [ $TIMEOUT -eq 0 ]; then
        echo "Harbor DB cannot reach within one minute."
        exit 1
    fi
}

clean_database_data() {
  echo "Droping existing databases">&2
  psql -U postgres -d template1 -h $HOSTNAME -c "drop database registry;"
  psql -U postgres -d template1 -h $HOSTNAME -c "drop database postgres;"
  psql -U postgres -d template1 -h $HOSTNAME -c "drop database notarysigner;"
  psql -U postgres -d template1 -h $HOSTNAME -c "drop database notaryserver;"

  echo "Creating clean database">&2
  psql -U postgres -d template1 -h $HOSTNAME -c "create database registry;"
  psql -U postgres -d template1 -h $HOSTNAME -c "create database postgres;"
  psql -U postgres -d template1 -h $HOSTNAME -c "create database notarysigner;"
  psql -U postgres -d template1 -h $HOSTNAME -c "create database notaryserver;"
}

restore_database() {
  echo "Restoring database">&2
  psql -U postgres -h $HOSTNAME registry < ${backup_dir}/registry.back
  psql -U postgres -h $HOSTNAME postgres < ${backup_dir}/postgres.back
  psql -U postgres -h $HOSTNAME notarysigner < ${backup_dir}/notarysigner.back
  psql -U postgres -h $HOSTNAME notaryserver < ${backup_dir}/notaryserver.back
}

cleanup_local_files(){
  echo "Cleaning up local files">&2
  rm harbor.tgz
  rm ${backup_dir}/registry.back
  rm ${backup_dir}/postgres.back
  rm ${backup_dir}/notarysigner.back
  rm ${backup_dir}/notaryserver.back
  rmdir ${backup_dir}
}

s3_download "$1"
extract_backup
wait_for_db_ready
clean_database_data
restore_database
cleanup_local_files

echo "All Harbor data restored"
