# Upgrade v0.22.x to v0.23.x

## Steps

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    bin/ck8s init
    ```
1. Check if any of the [deprecated configurations](https://github.com/kubernetes/ingress-nginx/blob/helm-chart-4.1.3/Changelog.md#113) are present in the wc-config.yaml

1. **Warning** regarding OpenSearch securityadmin:

    The new securityadmin job will reset the security plugin when it runs.
    This means that any user, role, role mapping etc. that was created manually will be removed.

    Either prepare a backup to restore after it runs, or consider disabling securityadmin to protect manually created resources.

1. Migrate OpenSearch alerting roles:

    > Skip this step if securityadmin was disabled in the previous step.

    This will help clear out alerting roles comparing them to the new default ones.
    As well as add example mappings for the new default roles.

    ```bash
    ./migration/v0.22.x-v0.23.x/migrate-opensearch-roles.sh
    ```

1. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```
1. Change user-alertmanager receiver to `null` if the default slack receiver is being used: `migration/v0.22.x-v0.23.x/user-alertmanager-reconfig.sh`
