# Restore Harbor

This document describes how to restore Harbor from a backup in S3 or Azure blob storage using the `./bin/ck8s harbor-restore` command.
_Note this restore is only designed for internal harbor database and not for an external database._
The script should be performed from the `compliantkubernetes-apps` root directory.

Before restoring the database, make sure that Harbor is installed.
It can be installed normally.

## Prerequisites

- Ensure `yq`, `sops`, `envsubst`and `kubectl` are installed and configured.
- Ensure `CK8S_CONFIG_PATH` is set correctly.
- Ensure the Harbor admin password is the same as in the old environment (needed by the init job).

## Usage

The script automates the steps previously outlined in this document.
It automatically detects your `objectStorage.type` (s3 or azure) from `${CK8S_CONFIG_PATH}/defaults/common-config.yaml`.

```bash
./bin/ck8s harbor-restore [--backup-id <specific_backup_id>] [--azure-rclone-fixup]
```

- **`--backup-id <specific_backup_id>`**: (Optional) Specify the backup to restore. This can be:
    - A numeric ID (e.g., `1747441979`). The script will form the path as `backups/ID.tgz`.
    - A filename (e.g., `1747441979.tgz`). The script will form the path as `backups/filename`.
    - A full path (e.g., `backups/1747441979.tgz`).
        If omitted, the latest backup will be used.
- **`--azure-rclone-fixup`**: (Optional, Azure Storage Type Only) If your `objectStorage.type` is `azure` and this flag is specified, the script runs an Rclone job to correct potential path issues for Harbor image data. This is typically needed if you are restoring in Azure from a backup that was an rclone destination from a non-Azure source (e.g., S3). See the "Azure Rclone Data Move" section below for more details.

### Listing Available Backups

To find a specific backup ID or filename, you can use the following commands. The backups are typically named with a Unix timestamp and have a `.tgz` extension (e.g., `1747441979.tgz`).

<details>
    <summary>S3</summary>

```bash
s3cmd --config <(sops -d ${CK8S_CONFIG_PATH}/.state/s3cfg.ini) ls s3://$(yq '.objectStorage.buckets.harbor' "${CK8S_CONFIG_PATH}/defaults/sc-config.yaml")/backups/
```

</details>

<details>
    <summary>Azure</summary>

```bash
export AZURE_LOCATION=$(yq '.objectStorage.azure.region' "${CK8S_CONFIG_PATH}/common-config.yaml" ) # Or your specific Azure location
./scripts/azure/storage-manager.sh list-harbor-backups
```

_(Note: `storage-manager.sh` might need `AZURE_ACCOUNT_NAME` and `AZURE_CONTAINER_NAME` to be set or derived correctly within the script or environment for listing backups. The restore script handles these for the restore process itself based on `CK8S_CONFIG_PATH` values.)_

</details>

### Example

To restore the latest backup (storage type will be auto-detected):

```bash
./bin/ck8s harbor-restore
```

To restore a specific backup using its numeric ID (storage type will be auto-detected):

```bash
./bin/ck8s harbor-restore --backup-id 1747614779
```

To restore a specific backup using its filename (storage type will be auto-detected):

```bash
./bin/ck8s harbor-restore --backup-id 1747528228.tgz
```

To restore an Azure backup and run the rclone path fixup job:

```bash
./bin/ck8s harbor-restore --backup-id <your_backup_id> --azure-rclone-fixup
```

## Manual Steps (If Required Post-Restore)

The script will provide reminders for these, but refer to the sections below if you encounter issues or have specific scenarios.

<details>
    <summary>Restore to a different domain</summary>

If the new harbor is using a dex instance with a different domain compared to the dex the old harbor was using, then when users login via dex harbor will not recognize them as the same user. Harbor will have the old OIDC users in the database, but when the new ones are created at first login they will conflict with the old ones and you will get a error like `failed to create user record: user <user> or email <email> already exists`.

To fix this you need to login as an admin user (you can login with the default, non-oidc admin at the URL `/account/sign-in`) and then delete the old users in the list of users. Users can then create new users again by logging. Then you need to set their permissions again.

</details>

<details>
    <summary>Restore between swift and s3/azure</summary>

If you are restoring Harbor from an environment that is using swift to an environment that is using s3 (or vice versa), then you need to modify some files in the object storage.

In swift Harbor stores most of the image data under `files/docker/` while in s3 it is stored under just `docker/`. This means that if you simply copy the data from swift to s3, then you need to rename all files under `files/docker/<filename>` to `docker/<filename>` or vice versa.

If you do not do this, then if you try to pull an old image you will get errors like: `Error response from daemon: manifest for <image> not found: manifest unknown: manifest unknown`

_(Note: The `./bin/ck8s harbor-restore` command currently supports S3 and Azure. Swift specific interactions are not built into the script.)_

</details>

<details>
    <summary>Azure Rclone Data Move (Handled by script)</summary>

If you are restoring Harbor in an Azure environment (i.e., `objectStorage.type` is `azure`) from a bucket that was previously a rclone destination where the source was not Azure (e.g. S3), the path for the Harbor image data might be incorrect. This is due to Harbor storing image data with an extra `/` at the start of the path when the storage is Azure.
The `./bin/ck8s harbor-restore` command attempts to handle this by running an rclone job to move the data **if your `objectStorage.type` is `azure` and you provide the `--azure-rclone-fixup` flag**.
If you use this flag in the appropriate Azure scenario, you do not need to perform these manual steps.

The original manual steps were:

```bash
# export S3_BUCKET=$(yq \'.objectStorage.buckets.harbor\' \"${CK8S_CONFIG_PATH}/defaults/sc-config.yaml\" )
# export AZURE_ACCOUNT=$(yq \'.objectStorage.azure.storageAccountName\' \"${CK8S_CONFIG_PATH}/common-config.yaml\" )
# export AZURE_KEY=$(sops -d --extract \'[\"objectStorage\"][\"azure\"][\"storageAccountKey\"]\' \"${CK8S_CONFIG_PATH}/secrets.yaml\" )
# envsubst > tmp-rclone-job.yaml < restore/harbor/harbor-rclone-azure.yaml
# ./bin/ck8s ops kubectl sc apply -f tmp-rclone-job.yaml
# ./bin/ck8s ops kubectl sc wait --for=condition=complete job -n rclone harbor-restore-rclone-move --timeout=-1s # Note: script uses -n harbor
# ./bin/ck8s ops kubectl sc delete -f tmp-rclone-job.yaml
# rm -v tmp-rclone-job.yaml
```

</details>

## Deprecated: Old Manual Restore Steps

The following sections detail the original manual commands. These are kept for reference but the `./bin/ck8s harbor-restore` command should be used.

<details>
    <summary>Old: Specific backup</summary>

By default the job will restore the latest backup.
The environment variable `SPECIFIC_BACKUP` can be used to specify which backup to use.

To get a list of available backups use:

<details>
    <summary>S3</summary>

```bash
s3cmd --config <(sops -d ${CK8S_CONFIG_PATH}/.state/s3cfg.ini) ls s3://${S3_BUCKET}/backups/
```

</details>

<details>
    <summary>Azure</summary>

```bash
export AZURE_LOCATION=swedencentral
./scripts/azure/storage-manager.sh list-harbor-backups
```

</details>

Then set:

```bash
export SPECIFIC_BACKUP=<backups/xxxxxxxxxx.tgz> # Optional, e.g. backups/1747441979.tgz
```

</details>

<details>
    <summary>Old: Restore job S3</summary>

Setup the necessary job.yaml and configmap:

```bash
# export S3_BUCKET=$(yq \'.objectStorage.buckets.harbor\' \"${CK8S_CONFIG_PATH}/defaults/sc-config.yaml\" )
# export S3_REGION_ENDPOINT=$(yq \'.objectStorage.s3.regionEndpoint\' \"${CK8S_CONFIG_PATH}/common-config.yaml\")
# envsubst > tmp-job.yaml < restore/harbor/restore-harbor-job.yaml
# ./bin/ck8s ops kubectl sc create configmap -n harbor restore-harbor --from-file=restore/harbor/restore-harbor.sh
```

</details>

<details>
    <summary>Old: Restore job Azure - Prepare for Harbor database restore</summary>

Setup the necessary job.yaml and configmap:

```bash
# envsubst > tmp-job.yaml < restore/harbor/restore-harbor-job-azure.yaml
# ./bin/ck8s ops kubectl sc create configmap -n harbor restore-harbor --from-file=restore/harbor/restore-harbor.sh
```

</details>

<details>
    <summary>Old: Restore common</summary>

While restoring we need to stop all harbor pods except for the database.

```bash
# ./bin/ck8s ops kubectl sc scale deployment --replicas 0 -n harbor --all
```

Create the job and wait until it has completed:

```bash
# ./bin/ck8s ops kubectl sc apply -n harbor -f restore/harbor/network-policies-harbor.yaml
# ./bin/ck8s ops kubectl sc apply -n harbor -f tmp-job.yaml
# ./bin/ck8s ops kubectl sc wait --for=condition=complete job -n harbor restore-harbor-job --timeout=-1s
```

Restore the pods:

```bash
# ./bin/ck8s ops kubectl sc scale deployment --replicas 1 -n harbor --all
```

Clean up:

```bash
# ./bin/ck8s ops kubectl sc delete -n harbor -f restore/harbor/network-policies-harbor.yaml
# ./bin/ck8s ops kubectl sc delete -n harbor -f tmp-job.yaml
# ./bin/ck8s ops kubectl sc delete configmap -n harbor restore-harbor
# rm -v tmp-job.yaml
```

</details>
