#!/usr/bin/env bash

# This script should not be run by itself, but from the `bin/` scripts.

set -euo pipefail

: "${bootstrap_path:?Missing bootstrap path}"
environment="${1}"
export storageclass_path="${bootstrap_path}/storageclass"
export namespaces_path="${bootstrap_path}/namespaces"

"${storageclass_path}/bootstrap.sh" "${environment}"
"${namespaces_path}/bootstrap.sh" "${environment}"
