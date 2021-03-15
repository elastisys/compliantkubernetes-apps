#!/bin/bash

# Simple script for generating a sample s3cfg for a couple of known
# and tested S3 providers.

function usage() {
    echo "Usage:" 1>&2
    echo "  $0 aws|exoscale|safespring|citycloud access_key secret_key host_base region" 1>&2
    exit 1
}

[ "$#" -lt 4 ] && echo "Too few arguments" && usage

cat <<EOF
access_key = $2
secret_key = $3
host_base = $4
bucket_location = $5
EOF
# Providers that support virtual-hosted-style access to buckets.
if [ "$1" = "aws" ] || [ "$1" = "exoscale" ]; then
cat <<EOF
host_bucket = %(bucket)s.$4
EOF
# Providers that only support path-style access to buckets.
elif [ "$1" = "safespring" ] || [ "$1" = "citycloud" ]; then
cat <<EOF
host_bucket = $4
EOF
else
echo "Unsupported S3 provider '$1'" && usage
fi
