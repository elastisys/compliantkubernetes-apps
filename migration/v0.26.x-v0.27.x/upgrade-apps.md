# Upgrade v0.26.x to v0.27.x

## Steps

1. Update apps configuration:
    This will take a backup into `backups/` before modifying any files.
    ```bash
    bin/ck8s init
    ```
1. Upgrade applications:
    ```bash
    bin/ck8s apply {sc|wc}
    ```
