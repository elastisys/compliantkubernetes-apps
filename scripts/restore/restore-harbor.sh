#!/bin/bash
# Check https://compliantkubernetes.io/operator-manual/disaster-recovery/ for instructions
set -e

HOSTNAME=harbor-database
backup_dir=backups

s3_download() {
    : "${S3_BUCKET:?Missing S3_BUCKET}"
    : "${S3_REGION_ENDPOINT:?Missing S3_REGION_ENDPOINT}"
    if [[ -n "$SPECIFIC_BACKUP" ]]; then
        backup_key=$SPECIFIC_BACKUP
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
  echo "Dropping existing databases">&2
  psql -U postgres -d template1 -h $HOSTNAME -c "drop database registry;"
  psql -U postgres -d template1 -h $HOSTNAME -c "drop database postgres;"

  echo "Creating clean database">&2
  psql -U postgres -d template1 -h $HOSTNAME -c "create database registry;"
  psql -U postgres -d template1 -h $HOSTNAME -c "create database postgres;"
}

restore_database() {
  echo "Restoring database">&2
  psql -U postgres -h $HOSTNAME registry < ${backup_dir}/registry.back
  psql -U postgres -h $HOSTNAME postgres < ${backup_dir}/postgres.back
}

cleanup_local_files(){
  echo "Cleaning up local files">&2
  rm harbor.tgz
  rm ${backup_dir}/registry.back
  rm ${backup_dir}/postgres.back
  # TODO: once v0.34 reaches EOL, these checks can be removed
  if [[ -f "${backup_dir}/notarysigner.back" ]]; then
    rm "${backup_dir}/notarysigner.back"
  fi
  if [[ -f "${backup_dir}/notaryserver.back" ]]; then
    rm "${backup_dir}/notaryserver.back"
  fi
  rmdir ${backup_dir}
}

s3_download
extract_backup
wait_for_db_ready
clean_database_data
restore_database
cleanup_local_files

echo "All Harbor data restored"
