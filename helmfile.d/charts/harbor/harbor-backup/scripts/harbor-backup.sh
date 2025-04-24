#!/usr/bin/env bash
set -e -o pipefail
: "${PG_HOSTNAME:?Missing PG_HOSTNAME}"
backup_dir="${BACKUP_DIR:-/backup}"
dump_dir="${backup_dir}/dbdump"
tarball_dir="${backup_dir}/tarball"
create_dir() {
  echo "creating backup directories" >&2
  mkdir -p "${dump_dir}"
  mkdir -p "${tarball_dir}"
}

wait_for_db_ready() {
  echo "checking connection to ${PG_HOSTNAME}:5432" >&2
  TIMEOUT=12
  while [ $TIMEOUT -gt 0 ]; do
    if pg_isready -h "$PG_HOSTNAME" | grep "accepting connections"; then
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

dump_database() {
  echo "Dumping database" >&2
  pg_dump -U postgres -h "$PG_HOSTNAME" registry | gzip -c >"${dump_dir}/registry.back.gz"
  pg_dump -U postgres -h "$PG_HOSTNAME" postgres | gzip -c >"${dump_dir}/postgres.back.gz"
}

create_tarball() {
  echo "Creating tarball" >&2
  tar zcvf "${tarball_dir}/harbor.tgz" "${dump_dir}"
}

s3_upload() {
  : "${BUCKET_NAME:?Missing BUCKET_NAME}"
  : "${S3_REGION_ENDPOINT:?Missing S3_REGION_ENDPOINT}"
  PATH_TO_BACKUP=s3://${BUCKET_NAME}"/backups/"$(date +%s).tgz

  echo "Uploading to s3 bucket ${PATH_TO_BACKUP}" >&2

  aws s3 cp "${tarball_dir}/harbor.tgz" "$PATH_TO_BACKUP" --endpoint-url="$S3_REGION_ENDPOINT"
}

s3_get_records() {
  before_date="$1"

  aws s3api list-objects \
    --bucket "${BUCKET_NAME}" \
    --endpoint-url "${S3_REGION_ENDPOINT}" \
    --prefix "backups/" \
    --query "Contents[?LastModified<='${before_date}'][].{Key: Key}"
}

s3_remove_path() {
  path=$1

  echo "deleting s3://${BUCKET_NAME}/${path}"
  aws s3 rm "s3://${BUCKET_NAME}/${path}" \
    --endpoint-url "${S3_REGION_ENDPOINT}"
}

gcs_upload() {
  : "${GCS_KEYFILE:?Missing GCS_KEYFILE}"
  : "${BUCKET_NAME:?Missing BUCKET_NAME}"
  PATH_TO_BACKUP="gs://${BUCKET_NAME}/backups/$(date +%s).tgz"

  echo "Uploading to gcs bucket ${PATH_TO_BACKUP}" >&2

  gsutil -o "Credentials:gs_service_key_file=${GCS_KEYFILE}" cp "${tarball_dir}/harbor.tgz" "${PATH_TO_BACKUP}"
}

gcs_get_records() {
  : "${GCS_KEYFILE:?Missing GCS_KEYFILE}"
  : "${BUCKET_NAME:?Missing BUCKET_NAME}"

  if [ $# -lt 1 ]; then
    echo "ERROR: Need to supply date to gcs_get_records" >&1
    exit 1
  fi

  before_date="$1"
  PATH_TO_BACKUPS="gs://${BUCKET_NAME}/backups/"

  # The jq command will do the following:
  # * Select all backups in the backups/ folder
  # * Select only entries older than given date (epoch time)
  # * Save name of path to key "Key"
  gsutil -o "Credentials:gs_service_key_file=${GCS_KEYFILE}" ls -L "${PATH_TO_BACKUPS}" |
    yq eval --output-format json --input-format yaml |
    jq '[to_entries | .[] | ' \
      'select(( .key | test("^gs:\/\/[^\/]+\/backups\/.+")) and ' \
      '(.value."Update time" | strptime("%a, %d %b %Y %H:%M:%S %Z") | mktime <= '"${before_date}"') ) | ' \
      '{Key: (.key | match("^gs:\/\/[^\/]+\/(.+)").captures[0].string)}]'
}

gcs_remove_path() {
  : "${GCS_KEYFILE:?Missing GCS_KEYFILE}"
  : "${BUCKET_NAME:?Missing BUCKET_NAME}"

  if [ $# -lt 1 ]; then
    echo "ERROR: Need to supply path to gcs_remove_path" >&1
    exit 1
  fi

  path=$1

  echo "deleting gs://${BUCKET_NAME}/${path}"
  gsutil -o "Credentials:gs_service_key_file=${GCS_KEYFILE}" rm "${BUCKET_NAME}/${path}"
}

azure_upload() {
  : "${AZURE_ACCOUNT_NAME:?Missing AZURE_ACCOUNT_NAME}"
  : "${AZURE_ACCOUNT_KEY:?Missing AZURE_ACCOUNT_KEY}"
  : "${AZURE_CONTAINER_NAME:?Missing AZURE_CONTAINER_NAME}"
  PATH_TO_BACKUP="https://${AZURE_ACCOUNT_NAME}.blob.core.windows.net/${AZURE_CONTAINER_NAME}/backups/$(date +%s).tgz"

  echo "Uploading to Azure Blob Storage bucket ${PATH_TO_BACKUP}" >&2

  az storage blob upload \
    --account-name "${AZURE_ACCOUNT_NAME}" \
    --account-key "${AZURE_ACCOUNT_KEY}" \
    --container-name "${AZURE_CONTAINER_NAME}" \
    --name "backups/$(date +%s).tgz" \
    --file "${tarball_dir}/harbor.tgz"
}

azure_get_records() {
  : "${AZURE_ACCOUNT_NAME:?Missing AZURE_ACCOUNT_NAME}"
  : "${AZURE_ACCOUNT_KEY:?Missing AZURE_ACCOUNT_KEY}"
  : "${AZURE_CONTAINER_NAME:?Missing AZURE_CONTAINER_NAME}"

  if [ $# -lt 1 ]; then
    echo "ERROR: Need to supply date to azure_get_records" >&2
    exit 1
  fi

  # List all blobs in the specified container and filter by date
  az storage blob list \
    --account-name "${AZURE_ACCOUNT_NAME}" \
    --account-key "${AZURE_ACCOUNT_KEY}" \
    --container-name "${AZURE_CONTAINER_NAME}" \
    --query "[?properties.lastModified <= '${before_date}'].{Name: name}"
}

azure_remove_path() {
  : "${AZURE_ACCOUNT_NAME:?Missing AZURE_ACCOUNT_NAME}"
  : "${AZURE_ACCOUNT_KEY:?Missing AZURE_ACCOUNT_KEY}"
  : "${AZURE_CONTAINER_NAME:?Missing AZURE_CONTAINER_NAME}"
  path=$1

  echo "deleting https://${AZURE_ACCOUNT_NAME}.blob.core.windows.net/${AZURE_CONTAINER_NAME}/${path}" >&2
  az storage blob delete \
    --account-name "${AZURE_ACCOUNT_NAME}" \
    --account-key "${AZURE_ACCOUNT_KEY}" \
    --container-name "${AZURE_CONTAINER_NAME}" \
    --name "${path}"
}

remove_old_backups() {
  : "${DAYS_TO_RETAIN:?Missing DAYS_TO_RETAIN}"

  if [[ ${S3_BACKUP} == "true" ]]; then
    before_date=$(date --iso-8601=seconds -d "-${DAYS_TO_RETAIN} days")
    now=$(date --iso-8601=seconds)

    del_records=$(s3_get_records "${before_date}")
    all_records=$(s3_get_records "${now}")
  elif [[ ${GCS_BACKUP} == "true" ]]; then
    before_date=$(date -d "-${DAYS_TO_RETAIN} days" +%s)
    now=$(date +%s)

    del_records=$(gcs_get_records "${before_date}")
    all_records=$(gcs_get_records "${now}")
  elif [[ ${AZURE_BACKUP} == "true" ]]; then
    before_date=$(date -d "-${DAYS_TO_RETAIN} days" +%s)
    now=$(date +%s)

    del_records=$(azure_get_records "${before_date}")
    all_records=$(azure_get_records "${now}")
  fi

  del_paths=()
  all_paths=()

  _jq() {
    echo "${row}" | base64 --decode | jq -r "${1}"
  }

  for row in $(echo "${del_records}" | jq -r '.[] | @base64'); do
    del_paths+=("$(_jq '.Key')")
  done

  for row in $(echo "${all_records}" | jq -r '.[] | @base64'); do
    all_paths+=("$(_jq '.Key')")
  done

  # Number of backups left if all old backups are removed.
  left=$(("${#all_paths[@]}" - "${#del_paths[@]}"))

  # We ALWAYS keep N backups even if their TTL has expired!
  if (("${left}" < "${DAYS_TO_RETAIN}")); then
    num_to_delete=$(("${#all_paths[@]}" - "${DAYS_TO_RETAIN}"))
  else
    num_to_delete="${#del_paths[@]}"
  fi

  for path in "${del_paths[@]::${num_to_delete}}"; do
    if [[ ${S3_BACKUP} == "true" ]]; then
      s3_remove_path "${path}"
    elif [[ ${GCS_BACKUP} == "true" ]]; then
      gcs_remove_path "${path}"
    elif [[ ${AZURE_BACKUP} == "true" ]]; then
      azure_remove_path "${path}"
    fi
  done
}

create_dir
wait_for_db_ready
dump_database
create_tarball
if [[ ${S3_BACKUP} == "true" ]]; then
  s3_upload
fi
if [[ ${GCS_BACKUP} == "true" ]]; then
  gcs_upload
fi
if [[ ${AZURE_BACKUP} == "true" ]]; then
  azure_upload
fi
remove_old_backups
