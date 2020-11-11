#!/bin/bash

set -eu -o pipefail

here="$(dirname "$(readlink -f "$0")")"
ck8s="${here}/../bin/ck8s"
source "${here}/common.bash"

export CK8S_FLAVOR="${CI_CK8S_FLAVOR:-dev}"
export CK8S_ENVIRONMENT_NAME="${CK8S_ENVIRONMENT_NAME:-apps-${CK8S_CLOUD_PROVIDER}-${CK8S_FLAVOR}-${GITHUB_RUN_ID}}"

# Initialize ck8s repository

"${ck8s}" init

# Add additional config changes here
config_update "wc" "falco.alerts.enabled" "true"
