#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

yq4 -i 'with(
  .opensearch.promIndexAlerts[];
  with(
    select(
      .prefix == "authlog-default" and .alertSizeMB < 2
    );
    .alertSizeMB = 2
  )
)' "${CK8S_CONFIG_PATH}/sc-config.yaml"
