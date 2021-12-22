# Upgrade v0.18.x to v0.19.0

## Prerequisites

1. **Important** in this release the `alertmanager` namespace on the workload cluster will be managed as an operator namespace instead of an user namespace (if it is currently used).
    This means that before upgrading to this version the namespace must be clear of any resources other than User Alertmanager.
    The configuration of User Alertmanager will be carried over, as well as the users set in the role bindings to provide access to User Alertmanager.

## Steps

1. Run the migration script `remove_deleted_rules_prometheus_alerts.sh` to remove the old Prometheus rules and alerts from both clusters
> **_WARNING:_** this will "hide" all the alerts until you run the `bin/ck8s apply` and recreate the rules and alerts

1. Run migration script: `copy-environment-variables.sh`

    This will copy over the variables set for the environment regarding cloud provider, environment name, and flavor to the new location: the common default config.

1. Run migration script `remove_old_metrics_server.sh`

    This will remove the old metrics-server components from the clusters.

1. If using User Alertmanager: Run migration script `user-alertmanager-config.sh`

    This will save configuration and user role bindings for User Alertmanager.
    Skip this step if this is not something you want to keep.

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    bin/ck8s init
    ```

    This will generate new `defaults/common-config.yaml` and `common-config.yaml`, which will contain common configuration options set for both the service and workload cluster. Any common option set for the service and workload cluster in the `service-config.yaml` and `workload-config.yaml` will be moved to `common-config.yaml` automatically.

1. If using User Alertmanager: Run migration script: `user-alertmanager-run.sh`

    This will remove User Alertmanager, update the user namespaces and role bindings, and reinstall User Alertmanager with the default configuration.

1. Delete deprecated parameter `fluentd.forwarder.queueLimitSizeBytes` in `sc-config.yaml`

1. Rename parameter `fluentd.forwarder.chunkLimitSizeBytes` to `fluentd.forwarder.chunkLimitSize` in `sc-config.yaml`

1. If you have custom/manual Prometheus rules installed you will need to update the labels in order form them to be picked by the correct Prometheus instance. e.g. service_cluster: "1" or workload_cluster: "1"

1. Run the migration script: `upgrade_prometheus_operator.sh`

1. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```

1. If using User Alertmanager: Run migration script: `user-alertmanager-reconfig.sh`

    This will reconfigure User Alertmanager with the stored configuration and role bindings.
    Skip this step if the previous step saving the configuration was skipped.
