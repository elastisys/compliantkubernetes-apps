
# [WIP] Upgrade v0.8.x to v0.9.0

You will need to follow these steps in order to upgrade each Compliant Kubernetes environment from v0.8.x to v0.9.0. The instructions assume that you work from the root of the `compliantkubernetes-apps` repository, has the latest changes already pulled and configured `CK8S_CONFIG_PATH` correctly.

1. Run init to get new defaults: `./bin/ck8s init`

2. The following configuration options must be manually updated in your configuration files:
  - Remove
    - `user.prometheusPassword`
    - `externalTrafficPolicy.whitelistRange.prometheus`
  - Replace
    - `influxDB.user` -> `influxDB.users.adminUser`
    - `influxDB.password` -> `influxDB.users.adminPassword`

3. Upgrade workload cluster applications
  ```
  ./bin/ck8s apply wc
  ```

4. Upgrade service cluster applications
  ```
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
