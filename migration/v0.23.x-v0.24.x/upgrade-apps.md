# Upgrade v0.23.x to v0.24.x

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
1. The new `capacityManagementAlerts` are enabled by default, check the alerts triggered by this rules

1. Remove the old `predictLinear` config: `migration/v0.23.x-v0.24.x/remove-old-predict-linear-config.sh`
