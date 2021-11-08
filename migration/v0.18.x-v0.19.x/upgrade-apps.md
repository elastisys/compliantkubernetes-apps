# Upgrade v0.18.x to v0.19.0

## Steps

1. Run the migration script `remove_deleted_rules_prometheus_alerts.sh` to remove the old Prometheus rules and alerts from both clusters
> **_WARNING:_** this will "hide" all the alerts until you run the `bin/ck8s apply` and recreate the rules and alerts

1. Run migration script: `copy-environment-variables.sh`

    This will copy over the variables set for the environment regarding cloud provider, environment name, and flavor to the new location: the common default config.

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    bin/ck8s init
    ```

    This will generate new `defaults/common-config.yaml` and `common-config.yaml`, which will contain common configuration options set for both the service and workload cluster. Any common option set for the service and workload cluster in the `service-config.yaml` and `workload-config.yaml` will be moved to `common-config.yaml` automatically.

1. Delete deprecated parameter `fluentd.forwarder.queueLimitSizeBytes` in `sc-config.yaml`

1. Rename parameter `fluentd.forwarder.chunkLimitSizeBytes` to `fluentd.forwarder.chunkLimitSize` in `sc-config.yaml`

1. If you have custom/manual Prometheus rules installed you will need to update the labels in order form them to be picked by the correct Prometheus instance. e.g. service_cluster: "1" or workload_cluster: "1"

1. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```
