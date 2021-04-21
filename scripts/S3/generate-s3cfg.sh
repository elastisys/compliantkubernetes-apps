#!/bin/bash

set -eu -o pipefail

# Simple script for generating a sample s3cfg for a couple of known
# and tested S3 providers.

function usage() {
    echo "Usage:" 1>&2
    echo "  $0 {aws|exoscale|safespring|citycloud} {access_key} {secret_key} {host_base} [region]" 1>&2
    echo "  host_base - the host (and port if other than default) of the service" 1>&2
    echo "  region - the location where the buckets should be stored. This is ignored for exoscale, safespring and citycloud." 1>&2
    echo "Examples:" 1>&2
    echo "  $0 aws abc 123 s3.amazonaws.com eu-north-1" 1>&2
    echo "  $0 exoscale abc 123 sos-ch-gva-2.exo.io" 1>&2
    echo "  $0 safespring abc 123 s3.sto1.safedc.net" 1>&2
    echo "  $0 cityloud abc 123 s3-kna1.citycloud.com:8080" 1>&2
    exit 1
}

[ "$#" -lt 4 ] && echo "Too few arguments" && usage

cat <<EOF
access_key = $2
secret_key = $3
EOF
if [ "$1" = "aws" ]; then
cat <<EOF
bucket_location = $5
EOF
elif [ "$1" = "exoscale" ]; then
cat <<EOF
host_base = $4
host_bucket = %(bucket)s.$4
EOF
elif [ "$1" = "safespring" ] || [ "$1" = "citycloud" ]; then
cat <<EOF
host_base = $4
host_bucket = $4
EOF
else
echo "Unsupported S3 provider '$1'" && usage
fi
