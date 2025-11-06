#!/usr/bin/env bash

set -u -o pipefail

here="$(dirname "$(readlink -f "$0")")"
root="$(dirname "$(dirname "$(readlink -f "$0")")")"
ck8s="${root}/bin/ck8s"
bin_path="${root}/bin"

# shellcheck source=pipeline/common.bash
source "${here}/common.bash"
# shellcheck source=bin/common.bash
source "${bin_path}/common.bash"

"${ck8s}" apply wc
apply_exit_code="${?}"

exit "${apply_exit_code}"
