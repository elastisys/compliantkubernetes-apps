#!/bin/bash

# Simple script for managing the creation and deletion of S3 buckets using s3cmd.
# Users can point to their s3cmd config file via the option '--s3cfg config-path'.
# If the path to the config file is not passed,  '~/.s3cfg' will be used.

set -e

readonly CREATE_ACTION="create"
readonly DELETE_ACTION="delete"
readonly ABORT_UPLOAD_ACTION="abort"

function usage() {
    echo "Usage:" 1>&2
    echo "  $0 [--s3cfg config-path] --create | -c bucket_name_1  [bucket_name_2 ...]" 1>&2
    echo "  $0 [--s3cfg config-path] --delete | -d bucket_name_1  [bucket_name_2 ...]" 1>&2
    echo "  $0 [--s3cfg config-path] --abort  | -a bucket_name_1  [bucket_name_2 ...]" 1>&2
    exit 1
}

if [ "$1" = "--s3cfg" ]; then
    [ "$#" -lt 4 ] && echo "Too few arguments" 1>&2 && usage
    s3cmd='s3cmd --config '"${2}"
    shift; shift
else
    [ "$#" -lt 2 ] && echo "Too few arguments" 1>&2 && usage
    s3cmd='s3cmd'
fi

case "$1" in
    -c | --create ) ACTION=$CREATE_ACTION
                    ;;
    -d | --delete ) ACTION=$DELETE_ACTION
                    ;;
    -a | --abort  ) ACTION=$ABORT_UPLOAD_ACTION
                    ;;
esac
shift

buckets="$*"

function create_bucket() { # arguments: bucket name
    local bucket_name="$1"

    echo "checking status of bucket [${bucket_name}]" >&2
    BUCKET_EXISTS=$(echo "$S3_BUCKET_LIST" | awk "\$3~/^s3:\/\/${bucket_name}$/ {print \$3}")

    if [ "$BUCKET_EXISTS" ]; then
        echo "bucket [${bucket_name}] already exists, do nothing" >&2
    else
        echo "bucket [${bucket_name}] does not exist, creating it now" >&2
        ${s3cmd} mb "s3://${bucket_name}"
    fi
}

function delete_bucket() { # arguments: bucket name
    local bucket_name="$1"

    echo "checking status of bucket [${bucket_name}]" >&2
    BUCKET_EXISTS=$(echo "$S3_BUCKET_LIST" | awk "\$3~/^s3:\/\/${bucket_name}$/ {print \$3}")

    if [ "$BUCKET_EXISTS" ]; then
        echo "Bucket [${bucket_name}] exists, deleting it now" >&2
        ${s3cmd} rb "s3://${bucket_name}" --force --recursive
    else
        echo "bucket [${bucket_name}] does not exist, do nothing" >&2
    fi
}

function abort_multipart_uploads() { # arguments: bucket name
    local bucket_name="$1"

    echo "checking status of bucket [${bucket_name}]" >&2
    ONGOING_UPLOADS=$(${s3cmd} multipart "s3://${bucket_name}" | \
                      awk 'FNR > 2 { print $2 " " $3 }') # header has two lines

    if [ -n "$ONGOING_UPLOADS" ]; then
        echo "The are ongoing multipart uploads, aborting them now"
        echo "$ONGOING_UPLOADS" | while read -r line ; do
            echo "Aborting $line"
            ${s3cmd} abortmp "$line"
        done
    else
        echo "No ongoing multipart uploads, do nothing"
    fi
}

# get a list of all the S3 buckets
S3_BUCKET_LIST=$(${s3cmd} ls)

if [[ "$ACTION" == "$CREATE_ACTION" ]]; then
    echo 'Create buckets (only if they do not exist)' >&2
    # shellcheck disable=SC2068
    for bucket in ${buckets[@]}; do
        create_bucket "$bucket"
    done
elif [[ "$ACTION" == "$DELETE_ACTION" ]]; then
    echo 'Delete buckets' >&2
    # shellcheck disable=SC2068
    for bucket in ${buckets[@]}; do
        delete_bucket "$bucket"
    done
elif [[ "$ACTION" == "$ABORT_UPLOAD_ACTION" ]]; then
    echo 'Abort multipart uploads to buckets' >&2
    # shellcheck disable=SC2068
    for bucket in ${buckets[@]}; do
        abort_multipart_uploads "$bucket"
    done
else
    echo 'Unknown action - Aborting!' >&2 && usage
    exit 1
fi
