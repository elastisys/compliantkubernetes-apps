# Upgrade v0.22.x to v0.23.x

## Steps

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    bin/ck8s init
    ```
1. Check if any of the [deprecated configurations](https://github.com/kubernetes/ingress-nginx/blob/helm-chart-4.1.3/Changelog.md#113) are present in the wc-config.yaml
1. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```
