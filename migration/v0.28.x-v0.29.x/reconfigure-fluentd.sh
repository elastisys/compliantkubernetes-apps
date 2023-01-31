#!/usr/bin/env bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?"Need to set CK8S_CONFIG_PATH!"}"

if [ ! -f "$CK8S_CONFIG_PATH/sc-config.yaml" ]; then
  echo "missing sc-config.yaml!"
  exit 1
fi
if [ ! -f "$CK8S_CONFIG_PATH/wc-config.yaml" ]; then
  echo "missing wc-config.yaml!"
  exit 1
fi

yqnull() {
  test "$(yq4 "$2" "$CK8S_CONFIG_PATH/$1-config.yaml")" = "null"
}

yqcopy() {
  if ! yqnull "$1" "$2"; then
    echo "  - copy: $2 to $3"
    yq4 -i "$3 = $2" "$CK8S_CONFIG_PATH/$1-config.yaml"
  fi
}

yqmove() {
  if ! yqnull "$1" "$2"; then
    echo "  - move: $2 to $3"
    yq4 -i "$3 = $2 | del($2)" "$CK8S_CONFIG_PATH/$1-config.yaml"
  fi
}

yqremove() {
  if ! yqnull "$1" "$2"; then
    echo "  - remove: $2"
    yq4 -i "del($2)" "$CK8S_CONFIG_PATH/$1-config.yaml"
  fi
}

if ! yqnull sc .fluentd; then
  echo "- sc: reconfigure"

  if yqnull sc .fluentd.enabled.scLogs; then
    yqcopy sc .fluentd.enabled .fluentd.scLogs.enabled
  fi
  yqmove sc .fluentd.forwarder.chunkLimitSize .fluentd.forwarder.buffer.chunkLimitSize
  yqmove sc .fluentd.forwarder.totalLimitSize .fluentd.forwarder.buffer.totalLimitSize
  yqremove sc .fluentd.forwarder.livenessProbe
  yqremove sc .fluentd.forwarder.readinessProbe
  yqremove sc .fluentd.forwarder.useRegionEndpoint
fi
if ! yqnull wc .fluentd; then
  echo "- wc: reconfigure"

  yqmove wc .fluentd.elasticsearch.buffer .fluentd.forwarder.buffer
  yqmove wc .fluentd.resources .fluentd.forwarder.resources
  yqmove wc .fluentd.tolerations .fluentd.forwarder.tolerations
  yqmove wc .fluentd.nodeSelector .fluentd.forwarder.nodeSelector
  yqmove wc .fluentd.affinity .fluentd.forwarder.affinity
fi
