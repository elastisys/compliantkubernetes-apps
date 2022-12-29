# Upgrade v0.27.x to v0.28.x

## Steps

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    bin/ck8s init
    ```

1. Migrate nginx service annotations from a string to a map

    ```
    ./migration/v0.27.x-v0.28.x/move-nginx-controller-service-annotation-to-map
    ```

1. Add new harbor credentials

    ```bash
    ./migration/v0.27.x-v0.28.x/add-registry-credentials.sh
    ```

1. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```

1. Removing the legacy datasources requires a pod restart.

    a. check if the grafana pods have restarted (restart them if not):

    ```bash
    bin/ck8s ops kubectl sc get po -n monitoring -l app.kubernetes.io/name=grafana
    ```

    b. check in the UI if the legacy datasources were removed
