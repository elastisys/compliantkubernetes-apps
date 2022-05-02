# Upgrade v0.20.x to v0.21.x

## Prerequisites

## Steps

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    bin/ck8s init
    ```

2. Remove grafana-ops chart with all the dashboards: `migration/v0.20.x-v0.21.x/remove-grafana-ops.sh`

3. Rollover all streams to make fluentd have all logging fields/mappings: `migration/v0.20.x-v0.21.x/data-stream-rollovers.sh`

4. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```
