# Upgrade v0.19.x to v0.20.0

## Prerequisites

## Steps

1. Run the migration script: `migration/v0.19.x-v0.20.x/move_log_retention_days.sh`

1. Run the migration script: `migration/v0.19.x-v0.20.x/move-alertmanager-groupby.sh`

1. Run the migration script: `migration/v0.19.x-v0.20.x/move-usergroups-user-grafana.sh`

1. Run the migration script: `migration/v0.19.x-v0.20.x/move-predict-linear.sh`

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    bin/ck8s init
    ```

1. Remove grafana-ops chart: `migration/v0.19.x-v0.20.x/remove-grafana-ops.sh`

1. Remove any potential nfs-provisioner config: `migration/v0.19.x-v0.20.x/remove-nfs-provisioner-config.sh`

1. Remove any potential influxDB config: `migration/v0.19.x-v0.20.x/remove-influxdb-config.sh`

1. If your cluster are using docker as container runtime, set `global.containerRuntime` in `common-config.yaml` to `docker`

    > To see which container runtime your nodes are running you can run `kubectl get nodes -owide` and check the `CONTAINER-RUNTIME` column.

1. Remove conflicting starboard secret:

    This was managed by starboard-operator and from now on it is managed by helm.

    ```bash
    bin/ck8s ops kubectl {sc|wc} -n monitoring delete secret starboard
    ```

1. Update starboard-operator custom resource definitions:

    ```bash
    bin/ck8s ops kubectl {sc|wc} apply -f helmfile/upstream/starboard-operator/crds
    ```

1. Update the thanos receiver pvc size: `migration/v0.19.x-v0.20.x/upgrade-thanos-receiver-pvc.sh`

    > [!NOTE]
    > You will need to manually delete `thanos.receiver.persistence` lines from sc-config.yaml.
    >
    > `vim $CK8S_CONFIG_PATH/sc-config.yaml`

1. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```

1. Check if thanos receiver sts was recreated: `bin/ck8s ops kubectl sc get sts thanos-receiver-receive -n thanos`, if not run a sync `bin/ck8s ops helmfile sc -l app=thanos sync`

1. If everything looks ok you can remove the influxdb pvc and namespace: `migration/v0.19.x-v0.20.x/remove-influxdb-pvc-ns.sh`
