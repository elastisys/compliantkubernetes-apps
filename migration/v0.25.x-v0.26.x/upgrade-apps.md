# Upgrade v0.24.x to v0.25.x

## Steps

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    bin/ck8s init
    ```

1. *Optional:* If you are upgrading an environment of an Elastisys customer then run this script to add a customer support message to the grafana/opensearch "welcoming dashboards":

    > **_NOTE:_** This script requires yq4
    ```bash
    ./migration/v0.25.x-v0.26.x/add-support-message.sh
    ```

1. *Optional:* You can remove the Opensearch role mapping `readall_and_monitor` from `${CK8S_CONFIG_PATH}/sc.config.yaml` if you aren't using it in any meaningful way

1. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```
