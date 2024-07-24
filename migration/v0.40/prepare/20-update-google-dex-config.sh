#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

EDITOR='yq4 -i "with(.dex.connectors[]; with(select(.config | has(\"adminEmail\")); .config.domainToAdminEmail.\"*\" = .config.adminEmail | del(.config.adminEmail)))"' sops "${CK8S_CONFIG_PATH}/secrets.yaml"
