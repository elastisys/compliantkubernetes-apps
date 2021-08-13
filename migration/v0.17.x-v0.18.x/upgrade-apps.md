# Upgrade v0.17.x to v0.18.0

1. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```

1. Run migration script: `./migration/v0.17.x-v0.18.x/remove-velero-backupstoragelocation.sh`

    This script removes the unused `backupstoragelocation` "aws/gcs". It has been switched to "defualt"
