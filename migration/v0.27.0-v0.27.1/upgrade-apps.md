# Upgrade v0.27.0 to v0.27.1

## Steps

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    bin/ck8s init
    ```

1. Add new harbor credentials

    ```bash
    ./migration/v0.27.0-v0.27.1/add-registry-credentials.sh
    ```

1. Migrate harbor jobservice port to ports (array)

    ```
    ./migration/v0.27.x-v0.28.x/move-harbor-jobservice-port-to-ports.sh
    ```

1. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```
