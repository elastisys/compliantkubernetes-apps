# Upgrade v0.19.x to v0.20.0

## Prerequisites

## Steps

1. Run the migration script: `move_log_retention_days.sh`

1. Run the migration script: `move-alertmanager-groupby.sh`

1. Run the migration script: `move-usergroups-user-grafana.sh`

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    bin/ck8s init
    ```

1. If your cluster are using docker as container runtime, set `global.containerRuntime` in `common-config.yaml` to `docker`

    > To see which container runtime your nodes are running you can run `kubectl get container -owide` and check the `CONTAINER-RUNTIME` column.

1. Remove conflicting starboard secret:

   This was managed by starboard-operator and from now on it is managed by helm.

   ```bash
   bin/ck8s ops kubectl {sc|wc} -n monitoring delete secret starboard
   ```

1. Update starboard-operator custom resource definitions:

   ```bash
   bin/ck8s ops kubectl {sc|wc} apply -f helmfile/upstream/starboard-operator/crds
   ```

1. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```
