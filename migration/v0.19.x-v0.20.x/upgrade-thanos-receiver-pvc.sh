#!/bin/bash

set -o pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

sc_config="${CK8S_CONFIG_PATH}/sc-config.yaml"

upgrade_receiver_pvc() {
    value=$(yq r "$1" "$2" | grep -o '[[:digit:]]*')

    if [[ "${value}" -ge 50 ]]; then
        echo "The PVC size for thanos receiver is set to: ${value}. This size is greater or equal with the new default, 50Gi. Skipping."
    else
        echo "The PVC size for thanos receiver than the new default, 50Gi. It will be updated."
        ./bin/ck8s ops kubectl sc delete sts --cascade=orphan -n thanos thanos-receiver-receive
        ./bin/ck8s ops kubectl sc patch pvc data-thanos-receiver-receive-0 -n thanos --type='json' -p="\"[{'op': 'replace', 'path': '/spec/resources/requests/storage', 'value':'50Gi'}]\""
        ./bin/ck8s ops kubectl sc patch pvc data-thanos-receiver-receive-1 -n thanos --type='json' -p="\"[{'op': 'replace', 'path': '/spec/resources/requests/storage', 'value':'50Gi'}]\""
        echo "Deleting the $2 from ${sc_config}"
        yq d -i "$1" "$2"
    fi
}

if [[ ! -f "${sc_config}" ]]; then
    echo "sc-config does not exist, skipping."
    exit 0
fi

upgrade_receiver_pvc "${sc_config}" "thanos.receiver.persistence.size"
