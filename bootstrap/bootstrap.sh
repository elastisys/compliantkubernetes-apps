#!/usr/bin/env bash

# This script should not be run by itself, but from the `bin/` scripts.

set -euo pipefail

: "${bootstrap_path:?Missing bootstrap path}"
environment="${1}"
export storageclass_path="${bootstrap_path}/storageclass"
export namespaces_path="${bootstrap_path}/namespaces"
export issuers_path="${bootstrap_path}/issuers"

"${storageclass_path}/bootstrap.sh" "${environment}"
"${bootstrap_path}/crds/bootstrap.sh" "${environment}"
"${namespaces_path}/bootstrap.sh" "${environment}"
"${issuers_path}/bootstrap.sh" "${environment}"
