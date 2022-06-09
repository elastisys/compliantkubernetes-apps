#!/usr/bin/env bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

sc_config="${CK8S_CONFIG_PATH}/sc-config.yaml"
if [[ ! -f "${sc_config}" ]]; then
    echo "Override sc-config does not exist, aborting."
    exit 1
fi

read_access='{"cluster_permissions":["cluster:admin/opendistro/alerting/alerts/get","cluster:admin/opendistro/alerting/destination/get","cluster:admin/opendistro/alerting/monitor/get","cluster:admin/opendistro/alerting/monitor/search"]}'
ack_alerts='{"cluster_permissions":["cluster:admin/opendistro/alerting/alerts/*"]}'
full_access='{"cluster_permissions":["cluster_monitor","cluster:admin/opendistro/alerting/*"],"index_permissions":[{"allowed_actions":["indices_monitor","indices:admin/aliases/get","indices:admin/mappings/get"],"index_patterns":["kubernetes-*","kubeaudit-*"]}]}'

migrate() {
    echo "$1:"

    role=$(yq r -j "$sc_config" "opensearch.extraRoles[role_name==$1].definition" | jq -cS)

    if [ -z "$role" ]; then
        echo "- missing role, skipping"

    elif yq x <(echo "$role") <(echo "$2") -P; then
        echo "- identical role, clearing"
        yq d -i "$sc_config" "opensearch.extraRoles[role_name==$1]"

    else
        echo -n "- modified role, clear from $sc_config?: [y/N]: "
        read -r reply
        if [[ "${reply}" != "y" ]]; then
            echo "- skipping"
        else
            echo "- clearing"
            yq d -i "$sc_config" "opensearch.extraRoles[role_name==$1]"
        fi
    fi

    mapping=$(yq r -j "$sc_config" "opensearch.extraRoleMappings[mapping_name==$1]" | jq -cS)
    if [ -z "$mapping" ]; then
        echo "- missing mapping, adding"
        yq w -i -P "$sc_config" "opensearch.extraRoleMappings[+].mapping_name" "$1"
        yq w -i -P "$sc_config" "opensearch.extraRoleMappings[mapping_name==$1].definition.users[0]" "set-me"
    else
        echo "- existing mapping, skipping"
    fi

    echo
}

migrate "alerting_read_access" "$read_access"
migrate "alerting_ack_alerts" "$ack_alerts"
migrate "alerting_full_access" "$full_access"

if [ "$(yq r "$sc_config" "opensearch.extraRoles")" = "[]" ]; then
    yq d -i "$sc_config" "opensearch.extraRoles"
fi

echo "done"
