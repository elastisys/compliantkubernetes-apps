#!/usr/bin/env bash

set -eu -o pipefail

usage() {
    echo "Usage: clean <wc|sc>" >&2
    exit 1
}

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

cluster="${1}"

if [[ $cluster != "wc" && $cluster != "sc" ]]; then
    usage
fi

"${scripts_path}/clean-${cluster}.sh"
