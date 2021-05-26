# Upgrade v0.15.x to v0.16.0

1. Checkout the new release: `git checkout v0.16.0`

1. Run migration script: `./migration/v0.15.x-v0.16.x/migrate-apps.sh`

1. Run init to get new defaults:

    ```bash
    ./bin/ck8s init {sc|wc}
    ```

1. Set `monitoring.rook.enabled` to `true` in both `sc-config.yaml` and `wc-config.yaml` if you want or need to monitor Rook.

1. Upgrade applications:

    ```bash
    ./bin/ck8s apply {sc|wc}
    ```
