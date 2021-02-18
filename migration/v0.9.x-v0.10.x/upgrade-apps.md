# Upgrade v0.9.x to v0.10.0

You will need to follow these steps in order to upgrade each Compliant Kubernetes environment from v0.9.x to v0.10.0. The instructions assume that you work from the root of the `compliantkubernetes-apps` repository, has the latest changes already pulled and configured `CK8S_CONFIG_PATH` correctly.

1. Checkout the new release: `git checkout v0.10.0`.

2. Run init to get new defaults: `./bin/ck8s init`

3. The following configuration options must be manually updated in your configuration files:

  - Remove from `wc-config.yaml`
    - `ck8sdash.*`
    - `externalTrafficPolicy.whitelistRange.ck8sdash`
    - `objectStorage.buckets.harbor`
    - `objectStorage.buckets.elasticsearch`
    - `objectStorage.buckets.influxDB`
    - `objectStorage.buckets.scFluentd`

  - Remove from `sc-config.yaml`
    - `ck8sdash.*`
    - `externalTrafficPolicy.whitelistRange.ck8sdash`

4. Check elasticsearch configuration in sc-config.yaml
  Make sure that the new `elasticsearch.dataNode.dedicatedPods` and `elasticsearch.clientNode.dedicatedPods` are set to the desired value (true or false) to avoid unintentional changes to the cluster topology.

4. Upgrade workload cluster applications
  ```bash
  ./bin/ck8s apply wc
  ```

5. Upgrade service cluster applications
  **Note**, during the upgrade, the opendistro roles will be reloaded, so make sure you've got sufficient backups of the ones you've manually added.

  ```bash
  # Upgrade Elasticsearch
  ./bin/ck8s ops helmfile sc -l app=opendistro apply

  # Open another teminal so that you can run kubectl while helmfile is running

  # Wait for master pod 0 to be up and for elasticsearch to have started

  # Reload roles.
  ./bin/ck8s ops kubectl sc -n elastic-system exec opendistro-es-master-0 -- chmod +x ./plugins/opendistro_security/tools/securityadmin.sh
  ./bin/ck8s ops kubectl sc -n elastic-system exec opendistro-es-master-0 -- ./plugins/opendistro_security/tools/securityadmin.sh \
      -f plugins/opendistro_security/securityconfig/roles.yml \
      -icl -nhnv \
      -cacert config/admin-root-ca.pem \
      -cert config/admin-crt.pem \
      -key config/admin-key.pem

  # Wait for release to finish installing

  # Upgrade rest
  ./bin/ck8s apply sc
  ```

10. Remove ck8sdash's grafana api keys
    Only needed if you acutally had ck8sdash running in either or both of the clusters.
    If Grafana has been restarted/reinstalled the api key will no longer be there.

  ```bash
  # Remove api key from ops grafana
  grafana_ops_user=<...>
  grafana_ops_pwd=<...>
  grafana_ops_url=https://grafana.ops.<...>

  api_key_id=$(curl -sk -u ${grafana_ops_user}:${grafana_ops_pwd} ${grafana_ops_url}/api/auth/keys | jq -r '.[] | select(.name=="ck8sdash-sc") | .id')
  curl -sk -u ${grafana_ops_user}:${grafana_ops_pwd} -X DELETE ${grafana_ops_url}/api/auth/keys/${api_key_id}

  # Remove api key from user grafana
  grafana_user=<...>
  grafana_pwd=<...>
  grafana_url=https://grafana.<...>

  api_key_id=$(curl -sk -u ${grafana_user}:${grafana_pwd} ${grafana_url}/api/auth/keys | jq -r '.[] | select(.name=="ck8sdash-wc") | .id')
  curl -sk -u ${grafana_user}:${grafana_pwd} -X DELETE ${grafana_url}/api/auth/keys/${api_key_id}
  ```
