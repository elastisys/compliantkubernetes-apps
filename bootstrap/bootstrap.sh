#!/usr/bin/env bash

# This script should not be run by itself, but from the `bin/` scripts.

set -euo pipefail

here="$(dirname "$(readlink -f "$0")")"

environment="${1}"

"${here}/namespaces/bootstrap.sh" "${environment}"
