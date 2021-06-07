#!/bin/bash

set -u -o pipefail

here="$(dirname "$(readlink -f "$0")")"
pipeline_dir="${here}"
ck8s="${here}/../bin/ck8s"
bin_path="${here}/../bin"

# shellcheck disable=SC1090
source "${here}/common.bash"
# shellcheck disable=SC1090
source "${bin_path}/common.bash"

"${ck8s}" apply wc
apply_exit_code="${?}"

"${pipeline_dir}/list-releases.bash" "workload_cluster"
echo "'${pipeline_dir}/list-releases.bash workload_cluster' exited with code: ${?}"

exit "${apply_exit_code}"
