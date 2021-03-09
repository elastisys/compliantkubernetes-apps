# Upgrade v0.11.x to v0.12.0

1. Checkout the new release: `git checkout v0.12.0`

1. Run init to get new defaults: `./bin/ck8s init`

1. Delete `issuers.letsencrypt.namespaces` from both `sc-config.yaml` and `wc-config.yaml`.

1. Upgrade applications
  ```bash
  ./bin/ck8s apply {sc|wc}
  ```
