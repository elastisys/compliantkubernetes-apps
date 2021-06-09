#!/bin/bash

set -u -o pipefail

here="$(dirname "$(readlink -f "$0")")"
pipeline_dir="${here}"
ck8s="${here}/../bin/ck8s"
bin_path="${here}/../bin"

# shellcheck source=pipeline/common.bash
source "${here}/common.bash"
# shellcheck source=bin/common.bash
source "${bin_path}/common.bash"

"${ck8s}" apply sc
apply_exit_code="${?}"

"${pipeline_dir}/list-releases.bash" "service_cluster"
echo "'${pipeline_dir}/list-releases.bash service_cluster' exited with code: ${?}"

exit "${apply_exit_code}"
