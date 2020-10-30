#!/usr/bin/env bash

set -euo pipefail

environment=$1
: "${issuers_path:?Missing issuers path}"

if [ "${environment}" = service_cluster ]; then
    "${issuers_path}"/scripts/sc-issuers.sh
fi
if [ "${environment}" = workload_cluster ]; then
    "${issuers_path}"/scripts/wc-issuers.sh
fi
