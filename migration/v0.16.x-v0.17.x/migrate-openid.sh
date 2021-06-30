#!/bin/bash

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

# Restart the master pods so that they mount the latest version of the secret after apply
"${here}/../../bin/ck8s" ops kubectl sc delete pod -n elastic-system -l role=master

# Wait 60 seconds before updating the config after master pod restart
sleep 60

# Make the script executable
"${here}/../../bin/ck8s" ops kubectl sc -n elastic-system exec opendistro-es-master-0 -- chmod +x ./plugins/opendistro_security/tools/securityadmin.sh
# Run the script to update the configuration
"${here}/../../bin/ck8s" ops kubectl sc -n elastic-system exec opendistro-es-master-0 -- ./plugins/opendistro_security/tools/securityadmin.sh \
    -f plugins/opendistro_security/securityconfig/config.yml \
    -icl -nhnv \
    -cacert config/admin-root-ca.pem \
    -cert config/admin-crt.pem \
    -key config/admin-key.pem

# Restart Kibana to run by the new configurations
"${here}/../../bin/ck8s" ops kubectl sc delete pod -n elastic-system -l role=kibana
