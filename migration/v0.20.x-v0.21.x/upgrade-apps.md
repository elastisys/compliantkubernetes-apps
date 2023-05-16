# Upgrade v0.20.x to v0.21.x

## Prerequisites
1. Run this, so you have all the latest required binaries installed locally

```bash
ansible-playbook -e 'ansible_python_interpreter=/usr/bin/python3' --ask-become-pass --connection local --inventory 127.0.0.1, get-requirements.yaml
```
## Steps

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    bin/ck8s init
    ```

2. Remove grafana-ops chart with all the dashboards: `migration/v0.20.x-v0.21.x/remove-grafana-ops.sh`

3. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```

4. After the upgrade, if you see errors that log

    ```log
    Rejected by OpenSearch [error type]: mapper_parsing_exception
    ```

    Rollover all streams to make fluentd have all logging fields/mappings: `migration/v0.20.x-v0.21.x/data-stream-rollovers.sh`
