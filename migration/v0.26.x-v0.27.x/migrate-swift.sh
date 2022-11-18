#!/usr/bin/env bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?"CK8S_CONFIG_PATH is unset"}"

default_common="$CK8S_CONFIG_PATH/defaults/common-config.yaml"
default_sc="$CK8S_CONFIG_PATH/defaults/sc-config.yaml"
config_common="$CK8S_CONFIG_PATH/common-config.yaml"
config_sc="$CK8S_CONFIG_PATH/sc-config.yaml"
secrets="$CK8S_CONFIG_PATH/secrets.yaml"

configs=( "$default_common" "$default_sc" "$config_common" "$config_sc" )

if [ ! -f "$secrets" ]; then
  echo "err: $secrets not found" >&2
  exit 1
fi

for config in "${configs[@]}"; do
  if [ ! -f "$config" ]; then
    echo "err: $config not found" >&2
    exit 1
  fi
done

merge="$(yq4 ea "explode(.) as \$config ireduce ({}; . * \$config)" "${configs[@]}")"

if [ "$(echo "$merge" | yq4 '.harbor.persistence.type')" != "swift" ]; then
  echo "skip: swift not enabled for harbor"
  exit 0
fi

echo "info: moving values harbor.persistence.swift to objectStorage.swift"
move_value() {
  value="$(echo "$merge" | yq4 ".$1 // \"unset\"")"
  if [ "$value" = "unset" ]; then
    echo "- skip: move $1 to $2"
  else
    echo "- info: move $1 to $2"
    yq4 -i ".$2 = \"$value\" | del(.$1)" "$config_sc"
  fi
}

move_value "harbor.persistence.swift.authVersion" "objectStorage.swift.authVersion"
move_value "harbor.persistence.swift.authURL" "objectStorage.swift.authUrl"
move_value "harbor.persistence.swift.regionName" "objectStorage.swift.region"
move_value "harbor.persistence.swift.userDomainName" "objectStorage.swift.domainName"
move_value "harbor.persistence.swift.projectDomainName" "objectStorage.swift.projectDomainName"
move_value "harbor.persistence.swift.projectID" "objectStorage.swift.projectId"
move_value "harbor.persistence.swift.tenantName" "objectStorage.swift.projectName"

if [ "$(echo "$merge" | yq4 '.harbor.persistence.swift // "unset"')" != "unset" ]; then
  echo "- info: clear harbor.persistence.swift"
  yq4 -i 'del(.harbor.persistence.swift)' "$config_sc"
fi

authUrl="$(echo "$merge" | yq4 '.objectStorage.swift.authUrl // "unset"')"
if [ -n "${authUrl##*/v3}" ]; then
  echo "- info: appending '/v3' to objectStorage.swift.authUrl"
  yq4 -i '.objectStorage.swift.authUrl = .objectStorage.swift.authUrl + "/v3"' "$config_sc"
fi

if [ "$(echo "$config_sc" | yq4 '.objectStorage.swift.domainId // "unset"')" == "unset" ]; then
  echo "- info: setting objectStorage.swift.domainId to empty string"
  yq4 -i '.objectStorage.swift.domainId = ""' "$config_sc"
fi

echo "info: moving secrets harbor.persistence.swift to objectStorage.swift"
if [ "$(sops --config "$CK8S_CONFIG_PATH/.sops.yaml" -d "$secrets" | yq4 '.harbor.persistence.swift // "unset"')" = "unset" ]; then
  echo "- skip: move secrets harbor.persistence.swift to objectStorage.swift"
else
  echo "- info: move secrets harbor.persistence.swift to objectStorage.swift"
  sops --config "$CK8S_CONFIG_PATH/.sops.yaml" -d "$secrets" \
    | yq4 '.objectStorage.swift = .harbor.persistence.swift | del(.harbor.persistence)' \
    | sops --input-type yaml --config "$CK8S_CONFIG_PATH/.sops.yaml" --output-type yaml -e /dev/stdin \
    > "${secrets}2" \
    && mv "${secrets}2" "${secrets}"
fi
