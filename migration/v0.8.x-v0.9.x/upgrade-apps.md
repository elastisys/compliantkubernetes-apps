
# [WIP] Upgrade v0.8.x to v0.9.0

You will need to follow these steps in order to upgrade each Compliant Kubernetes environment from v0.8.x to v0.9.0. The instructions assume that you work from the root of the `compliantkubernetes-apps` repository, has the latest changes already pulled and configured `CK8S_CONFIG_PATH` correctly.

1. This is an optional step. The default resource requests for Harbor pods have been updated. To get these new values you must remove the current values in your config (`resources:` yaml blocks under `harbor:`) from `sc-config.yaml` before running `./bin/ck8s init` in the next step.

2. Run init to get new defaults: `./bin/ck8s init`

3. The following configuration options must be manually updated in your configuration files:
  - Remove
    - `user.prometheusPassword`
    - `externalTrafficPolicy.whitelistRange.prometheus`
    - `global.dnsPrefix`

  - Remove from `wc-config.yaml`
    - `opa.enforcements.imageRegistry`
    - `opa.enforcements.networkPolicies`
    - `opa.enforcements.resources`

  - Replace in `sc-config.yaml`
    - `global.storageClass` -> `storageClasses.default`
    - `influxDB.user`     -> `influxDB.users.adminUser`
    - `influxDB.password` -> `influxDB.users.adminPassword`
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

  # Remove all letsencrypt relases
  for namespace in $(./bin/ck8s ops helm wc list --all-namespaces | grep -F letsencrypt | awk '{ print $2 }'); do
      ./bin/ck8s ops helm wc uninstall letsencrypt -n ${namespace}
  done

  # Upgrade
  ./bin/ck8s apply wc
  ```

5. Upgrade service cluster applications
  ```bash

  # Destroy old fluentd releases
  ./bin/ck8s ops helmfile sc -l app=fluentd destroy
  ./bin/ck8s ops helmfile sc -l app=fluentd-aggregator destroy

  # Remove all letsencrypt relases
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

  # You might have to restart the grafana pod if you don't see metrics from the workload cluster
  ```
