# Upgrade v0.19.x to v0.20.0

## Prerequisites

## Steps

1. Run the migration script: `move_log_retention_days.sh`

2. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    bin/ck8s init
    ```

3. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```
