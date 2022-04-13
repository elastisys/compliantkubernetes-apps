# Upgrade v0.20.0 to v0.21.1

## Prerequisites

## Steps

1. Remove grafana-ops chart with all the dashboards: `migration/v0.20.0-v0.20.1/remove-grafana-ops.sh`

1. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```
