# Upgrade v0.20.x to v0.21.x

## Prerequisites

## Steps

1. Remove grafana-ops chart with all the dashboards: `migration/v0.20.x-v0.21.x/remove-grafana-ops.sh`

2. Rollover all streams to make fluentd have all logging fields/mappings: `migration/v0.20.x-v0.21.x/data-stream-rollovers.sh`

3. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```
