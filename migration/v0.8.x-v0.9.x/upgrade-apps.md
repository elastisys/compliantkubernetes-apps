
# Upgrade v0.8.x to v0.9.0

You will need to follow these steps in order to upgrade each Compliant Kubernetes environment from v0.8.x to v0.9.0. The instructions assume that you work from the root of the `compliantkubernetes-apps` repository, has the latest changes already pulled and configured `CK8S_CONFIG_PATH` correctly.

1. Checkout the new release: `git checkout v0.9.0`.

2. Update helm to v3.5.0.

3. Optional

    The default resource requests for Harbor pods have been updated.
    To get these new values you must remove the current values in your config (`resources:` yaml blocks under `harbor:`) from `sc-config.yaml` before running `./bin/ck8s init` in the next step.

4. Replace the config option `global.environmentName` with `global.clusterName` run `./migration/v0.8.x-v0.9.x/migrate-config.sh`.

4. Run init to get new defaults: `./bin/ck8s init`

3. The following configuration options must be manually updated in your configuration files:
  - Remove from `secrets.yaml`
    - `user.prometheusPassword`

  - Remove from `wc-config.yaml`
    - `global.dnsPrefix`
    - `opa.enforcements.imageRegistry`
    - `opa.enforcements.networkPolicies`
    - `opa.enforcements.resources`
    - `externalTrafficPolicy.whitelistRange.prometheus`

  - Remove from `sc-config.yaml`
    - `global.dnsPrefix`

  - Replace in `sc-config.yaml`
    - `global.storageClass`       -> `storageClasses.default`
    - `influxDB.user`             -> `influxDB.users.adminUser`
    - `influxDB.password`         -> `influxDB.users.adminPassword`
    - `fluentd.resources`         -> `fluentd.forwarder.resources`
    - `fluentd.tolerations`       -> `fluentd.forwarder.tolerations`
    - `fluentd.affinity`          -> `fluentd.forwarder.affinity`
    - `fluentd.nodeSelector`      -> `fluentd.forwarder.nodeSelector`
    - `fluentd.useRegionEndpoint` -> `fluentd.forwarder.useRegionEndpoint`

  - Replace in `wc-config.yaml`
    - `global.storageClass` -> `storageClasses.default`

  - Pay special attention to the `storageClasses` configuration to make sure that it is configured according to what's in your cluster.
  If you have set `storageClasses.nfs.enabled: true` then make sure that you set the ip address to the nfs server in `nfsProvisioner.server`.

4. Upgrade workload cluster applications
  ```bash

  # Optional, only if you have alertmanager installed and you want to update the basic auth password.
  ./bin/ck8s ops helmfile wc -l app=user-alertmanager destroy

  # Remove all letsencrypt releases
  for namespace in $(./bin/ck8s ops helm wc list --all-namespaces | grep -F letsencrypt | awk '{ print $2 }'); do
      ./bin/ck8s ops helm wc uninstall letsencrypt -n ${namespace}
  done

  # Upgrade
  ./bin/ck8s apply wc
  ```

5. Upgrade service cluster applications
  ```bash

  # Remove elasticsearch-exporter
  ./bin/ck8s ops helm sc uninstall elasticsearch-exporter -n elastic-system

  # Destroy old fluentd releases
  ./bin/ck8s ops helmfile sc -l app=fluentd destroy
  ./bin/ck8s ops helmfile sc -l app=fluentd-aggregator destroy

  # Remove all letsencrypt releases
  for namespace in $(./bin/ck8s ops helm sc list --all-namespaces | grep -F letsencrypt | awk '{ print $2 }'); do
      ./bin/ck8s ops helm sc uninstall letsencrypt -n ${namespace}
  done

  # Upgrade
  ./bin/ck8s apply sc

  # Create new InfluxDB users

  # Exec into InfluxDB pod
  ./bin/ck8s ops kubectl sc -n influxdb-prometheus exec -it influxdb-0 -c influxdb -- bash

  # Execute the following commands inside the pod
  influx -username ${INFLUXDB_ADMIN_USER} -password ${INFLUXDB_ADMIN_PASSWORD} -execute "CREATE USER ${INFLUXDB_WCWRITER_USER} WITH PASSWORD '${INFLUXDB_WCWRITER_PASSWORD}'"
  influx -username ${INFLUXDB_ADMIN_USER} -password ${INFLUXDB_ADMIN_PASSWORD} -execute "CREATE USER ${INFLUXDB_SCWRITER_USER} WITH PASSWORD '${INFLUXDB_SCWRITER_PASSWORD}'"
  influx -username ${INFLUXDB_ADMIN_USER} -password ${INFLUXDB_ADMIN_PASSWORD} -execute "GRANT WRITE ON "workload_cluster" TO "${INFLUXDB_WCWRITER_USER}""
  influx -username ${INFLUXDB_ADMIN_USER} -password ${INFLUXDB_ADMIN_PASSWORD} -execute "GRANT WRITE ON "service_cluster" TO "${INFLUXDB_SCWRITER_USER}""

  # If the new grafana pod can't start due to it being unable to mount the volume because
  # it still in use by the old pod you'll have to delete the old grafana pod

  # List user-grafana pods
  ./bin/ck8s ops kubectl sc -n monitoring get pods -l app.kubernetes.io/instance=user-grafana

  # Delete the old pod (the one that's not in init phase).
  ./bin/ck8s ops kubectl sc -n monitoring delete pod user-grafana-<hash>

  # If you don't see any wc metrics in ops grafana, check it's logs and if you see
  # error="http: proxy error: dial tcp: lookup wc-scraper-prometheus-instance on 10.96.0.10:53: no such host"
  # you'll need to restart the pod
  ./bin/ck8s ops kubectl sc -n monitoring delete pod -l app.kubernetes.io/instance=kube-prometheus-stack,app.kubernetes.io/name=grafana


  ```
