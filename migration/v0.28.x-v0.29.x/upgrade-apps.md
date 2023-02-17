# Upgrade v0.28.x to v0.29.x

## Steps

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    bin/ck8s init
    ```

1. Run migration script `remove_old_metrics_server.sh`

    This will remove the old metrics-server components from the clusters.

1. Before upgrading, destroy `kured` in sc & wc
    ```bash
    ./bin/ck8s ops helmfile sc -l app=kured destroy
    ./bin/ck8s ops helmfile wc -l app=kured destroy
    ```

1. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```
