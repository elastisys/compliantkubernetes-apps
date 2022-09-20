# Upgrade v0.24.x to v0.25.x

## Steps

1. Create a backup for harbor

    ```
    ./bin/ck8s ops kubectl sc create job -n harbor harbor-backup-v026 --from=cronjobs/harbor-backup-cronjob
    ./bin/ck8s ops kubectl sc wait --for=condition=complete job -n harbor harbor-backup-v026 --timeout=-1s
    ```

1. Login into harbor and check what projects, images, users, robot accounts, etc exists. As these will be restored after the upgrade

1. Update apps configuration:

    This will take a backup into `backups/` before modifying any files.

    ```bash
    bin/ck8s init
    ```

1. Migrate harbor jobservice persistance storage size variable and prepare harbor for upgrade.

    ```
    ./migration/v0.25.x-v0.26.x/migrate-harbor-database-variables.sh
    ./bin/ck8s ops kubectl sc delete ingress -n harbor --all
    ./bin/ck8s ops kubectl sc delete jobs -n harbor init-harbor-job
    ```

1. *Optional:* If you are upgrading an environment of an Elastisys customer then run this script to add a customer support message to the grafana/opensearch "welcoming dashboards":

    > **_NOTE:_** This script requires yq4
    ```bash
    ./migration/v0.25.x-v0.26.x/add-support-message.sh
    ```

1. *Optional:* You can remove the Opensearch role mapping `readall_and_monitor` from `${CK8S_CONFIG_PATH}/sc.config.yaml` if you aren't using it in any meaningful way

1. Apply `starboard-operator` to temporarly remove the starboard psp

    ```bash
    bin/ck8s ops helmfile {sc|wc} -l app=starboard-operator apply
    ```

1. Upgrade applications:

    ```bash
    bin/ck8s apply {sc|wc}
    ```

1. Restore harbor by following the documentation for restoring harbor.
   Ensure that it is the new config map that is added to the cluster.
   [Restore documentation](../../scripts/restore/README.md)

1. Login into harbor and check that projects, images, users, robot accounts, etc exists after the restore is completed.

1. Delete old harbor pvc

    ```
    ./bin/ck8s ops kubectl sc delete pvc -n harbor data-harbor-harbor-redis-0 data-harbor-harbor-trivy-0 database-data-harbor-harbor-database-0 harbor-harbor-jobservice
    ```

1. Remove any old stuck jobs in the monitoring namespace. Other wise starboard operator will not create any new jobs.

    ```
    ./bin/ck8s ops kubectl sc delete jobs -n monitoring --all
    ./bin/ck8s ops kubectl wc delete jobs -n monitoring --all
    ```
