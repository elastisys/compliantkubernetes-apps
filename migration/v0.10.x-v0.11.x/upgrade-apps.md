# Upgrade v0.10.x to v0.11.0

1. Checkout the new release: `git checkout v0.11.0`

1. Upgrade the following programs:
    - `helm` to `v3.5.2`.
    - `kubectl` to `v1.19.8`.
    - `helmfile` to `v0.138.4`.

1. Run init to get new defaults: `./bin/ck8s init`

1. Change the `global.ck8sVersion` to `0.11.0` for `wc-config.yaml` and `sc-config.yaml`

1. Run apply to apply the changes for the service cluster: `./bin/ck8s apply sc`

1. Run apply to apply the changes for the workload cluster: `./bin/ck8s apply wc`
