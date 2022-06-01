# Upgrade v0.21.x to v0.22.x

## Steps

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    bin/ck8s init
    ```
2. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```
