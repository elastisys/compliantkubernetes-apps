# Upgrade v0.24.x to v0.25.x

## Steps

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    bin/ck8s init
    ```

1. Migrate harbor redis variables

    ```console
    migration/v0.24.x-v0.25.x/migrate-harbor-redis-variables.sh
    ```

1. Migrate harbor database variables

    ```console
    migration/v0.24.x-v0.25.x/migrate-harbor-database-variables.sh
    ```

1. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```
