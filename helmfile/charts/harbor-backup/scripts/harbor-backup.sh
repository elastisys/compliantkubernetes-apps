#!/bin/bash
set -e
: "${PG_HOSTNAME:?Missing PG_HOSTNAME}"
backup_dir=backups
create_dir(){
    echo "creating backup directory" >&2
    mkdir -p ${backup_dir}
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
    echo "Dumping database"  >&2
    pg_dump -U postgres -h "$PG_HOSTNAME" registry > ${backup_dir}/registry.back
    pg_dump -U postgres -h "$PG_HOSTNAME" postgres > ${backup_dir}/postgres.back
    pg_dump -U postgres -h "$PG_HOSTNAME" notarysigner > ${backup_dir}/notarysigner.back
    pg_dump -U postgres -h "$PG_HOSTNAME" notaryserver > ${backup_dir}/notaryserver.back
}

create_tarball() {
    echo "Creating tarball" >&2
    tar zcvf harbor.tgz $backup_dir
    mv harbor.tgz /backup/harbor.tgz
}

s3_upload() {

    : "${S3_BUCKET:?Missing S3_BUCKET}"
    : "${S3_REGION_ENDPOINT:?Missing S3_REGION_ENDPOINT}"
    echo "Uploading to s3 bucket s3://${S3_BUCKET}/backups/$(date +%s).sql.gz" >&2

    PATH_TO_BACKUP=s3://${S3_BUCKET}"/backups/"$(date +%s).sql.gz

    aws s3 cp /backup/harbor.tgz "$PATH_TO_BACKUP" --endpoint-url="$S3_REGION_ENDPOINT"
}

get_records() {
    before_date="$1"

    aws s3api list-objects \
        --bucket "${S3_BUCKET}" \
        --endpoint-url "${S3_REGION_ENDPOINT}" \
        --prefix "backups/" \
        --query "Contents[?LastModified<='${before_date}'][].{Key: Key}"
}

remove_old_backups () {
    : "${DAYS_TO_RETAIN:?Missing DAYS_TO_RETAIN}"
    before_date=$(date --iso-8601=seconds -d "-${DAYS_TO_RETAIN} days")
    now=$(date --iso-8601=seconds)

    del_records=$(get_records "${before_date}")
    all_records=$(get_records "${now}")

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
    if (( "${left}" < "${DAYS_TO_RETAIN}" )); then
        num_to_delete=$(("${#all_paths[@]}" - "${DAYS_TO_RETAIN}"))
    else
        num_to_delete="${#del_paths[@]}"
    fi

    for path in "${del_paths[@]::${num_to_delete}}"; do
        echo "deleting s3://${S3_BUCKET}/${path}"
        aws s3 rm "s3://${S3_BUCKET}/${path}" \
            --endpoint-url "${S3_REGION_ENDPOINT}"
    done
}

create_dir
wait_for_db_ready
dump_database
create_tarball
s3_upload
remove_old_backups
