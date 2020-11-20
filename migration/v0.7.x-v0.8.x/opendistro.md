Here are the instructions you'll need to carry out in order to upgrade the opendistro deployment.

```
## Update opendistro deployment

# Generate new config
./bin/ck8s init

# Update configuration, pay attention to the release notes for replaced and removed variables

# Deploy new release
./bin/ck8s ops helmfile sc -l app=opendistro apply

# Wait for master pod 0 to be up and for elasticsearch to have started

# Reload security config
./bin/ck8s ops kubectl sc -n elastic-system exec opendistro-es-master-0 -- chmod +x ./plugins/opendistro_security/tools/securityadmin.sh
./bin/ck8s ops kubectl sc -n elastic-system exec opendistro-es-master-0 -- ./plugins/opendistro_security/tools/securityadmin.sh \
    -cd plugins/opendistro_security/securityconfig/ \
    -icl -nhnv \
    -cacert config/admin-root-ca.pem \
    -cert config/admin-crt.pem \
    -key config/admin-key.pem

# Wait for release to finish


## Clean up old legacy index templates

# Get elasticsearch admin password
es_admin_pwd=$(pushd "${CK8S_CONFIG_PATH}" > /dev/null && sops exec-file secrets.yaml 'yq r {} elasticsearch.adminPassword' && popd > /dev/null)

# Get url to elasticsearch
es_url="https://elastic.$(yq r ${CK8S_CONFIG_PATH}/sc-config.yaml global.opsDomain)"

# Remove old legacy index templates
curl -u "admin:${es_admin_pwd}" -k -X DELETE "${es_url}/_template/kubernetes
curl -u "admin:${es_admin_pwd}" -k -X DELETE "${es_url}/_template/other
curl -u "admin:${es_admin_pwd}" -k -X DELETE "${es_url}/_template/kubeaudit
```
