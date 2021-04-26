# Upgrade v0.14.x to v0.15.0

1. Checkout the new release: `git checkout v0.15.0`

1. Run init to get new defaults:
    ```bash
    ./bin/ck8s init
    ```

1. Delete `restore.*` from `sc-config.yaml`.

1. Upgrade applications:
    ```bash
    ./bin/ck8s apply {sc|wc}
    ```
