# Upgrade v0.18.x to v0.19.0

## Prerequisites

1. **Important** in this release the `alertmanager` namespace on the workload cluster will be managed as an operator namespace instead of an user namespace (if it is currently used).
    This means that before upgrading to this version the namespace must be clear of any resources other than User Alertmanager.
    The configuration of User Alertmanager will be carried over, as well as the users set in the role bindings to provide access to User Alertmanager.

## Steps

1. Run migration script: `copy-environment-variables.sh`

    This will copy over the variables set for the environment regarding cloud provider, environment name, and flavor to the new location: the common default config.

1. If using User Alertmanager: Run migration script `user-alertmanager-config.sh`

    This will save configuration and user role bindings for User Alertmanager.
    Skip this step if this is not something you want to keep.

1. Run migration script: `opensearch-migration-configuration.sh`

    This will migrate the configuration and secrets from ODFE to OpenSearch.
    All settings will be carried over from `elasticsearch` to `opensearch`, and from `kibana` to `opensearch.dashboards`.

    Review and tweak the configuration in `sc-config.yaml` and `wc-config.yaml` according to your preferences.
    Index template settings prefixed with `opendistro.*` must be updated and changed to use the prefix `plugins.*` instead.

    By default it will configure OpenSearch using the subdomain `opensearch` on `ops.${DOMAIN}`, OpenSearch Dashboards using the subdomain `opensearch` on `${DOMAIN}`, and the snapshot repository using the bucket `${ENVIRONMENT_NAME}-opensearch`.
    **These must be prepared for the migration.**
    The bucket is not needed if snapshots are disabled.

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    bin/ck8s init
    ```

    This will generate new `defaults/common-config.yaml` and `common-config.yaml`, which will contain common configuration options set for both the service and workload cluster. Any common option set for the service and workload cluster in the `service-config.yaml` and `workload-config.yaml` will be moved to `common-config.yaml` automatically.

1. Run migration script `curator-retention.sh`

    This will update the curator retention to the new configuration way.
    This script is only relevant if you have overridden the defaults.

1. Run the migration script `remove_deleted_rules_prometheus_alerts.sh` to remove the old Prometheus rules and alerts from both clusters

    > **_WARNING:_** this will "hide" all the alerts until you run the `bin/ck8s apply` and recreate the rules and alerts

1. Run migration script `remove_old_metrics_server.sh`

    This will remove the old metrics-server components from the clusters.

1. If using User Alertmanager: Run migration script: `user-alertmanager-run.sh`

    This will remove User Alertmanager, update the user namespaces and role bindings, and reinstall User Alertmanager with the default configuration.

1. Migrate from ODFE to OpenSearch:

    This will set up a fresh OpenSearch cluster and migrate the data from ODFE via snapshots if enabled.
    **Note** that this will *not* carry over security settings.
    Any user, role, or rolemapping that has been manually created must be either be added into the configuration manifests or later manually added when the data migration is complete.

    If there is enough resources in the service cluster, and OpenSearch will be running under a new subdomain, then the two clusters can run in parallel during migration allowing you to verify that everything is carried over.
    **Note** that this will introduce authentication issues later for ODFE when Dex is updated, as the connector to Kibana will be removed.
    So make sure that you are already signed in to Kibana when you start if go with that method.

    Running `init` will generate new secrets for OpenSearch, if you want set specific passwords or reuse ones used for ODFE change them now.

    Run the script `opensearch-migration-run.sh` and it will perform the migration steps.
    For each destructive task the script will prompt for confirmation.

1. Delete deprecated parameter `fluentd.forwarder.queueLimitSizeBytes` in `sc-config.yaml`

1. Rename parameter `fluentd.forwarder.chunkLimitSizeBytes` to `fluentd.forwarder.chunkLimitSize` in `sc-config.yaml`

1. If you have custom/manual Prometheus rules installed you will need to update the labels in order form them to be picked by the correct Prometheus instance. e.g. service_cluster: "1" or workload_cluster: "1"

1. Run the migration script: `upgrade_prometheus_operator.sh`

1. Note on InfluxDB PVC size:

    The default value for InfluxDBs PVC has changed, and if you have not previously defined a size for it then it will try and fail to patch the StatefulSet.
    Either pin the current size by adding it into the override `sc-config.yaml` or remove the StatefulSet using `--cascade=false` to let the change apply.
    You might have to manually edit the PVC to set the new size after the apply.

1. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```

1. If using User Alertmanager: Run migration script: `user-alertmanager-reconfig.sh`

    This will reconfigure User Alertmanager with the stored configuration and role bindings.
    Skip this step if the previous step saving the configuration was skipped.

1. Clean up after ODFE:

    Run script `opensearch-migration-clean.sh`, this will delete deprecated parameters for ODFE in `secrets.yaml`, `sc-config.yaml` and `wc-config.yaml`.

1. You will need to restart the influxdb pod in order for it to load the new configmap:

    ```bash
    bin/ck8s ops kubectl sc delete po influxdb-0 -n influxdb-prometheus
    ```
