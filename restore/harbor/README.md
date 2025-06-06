# Restore Harbor

With the k8s job you can restore the database in Harbor from a backup in S3 or Azure blob storage.
_Note this restore is only designed for internal harbor database and not for an external database_
The steps should be performed from the `compliantkubernetes-apps` root directory.

Before restoring the database, make sure that Harbor is installed.
It can be installed normally.

## Specific backup

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
export SPECIFIC_BACKUP=<backups/xxxxxxxxxx.sql.gz> # Optional
```

## Restore job S3

Setup the necessary job.yaml and configmap:

```bash
export S3_BUCKET=$(yq '.objectStorage.buckets.harbor' "${CK8S_CONFIG_PATH}/defaults/sc-config.yaml" )
export S3_REGION_ENDPOINT=$(yq '.objectStorage.s3.regionEndpoint' "${CK8S_CONFIG_PATH}/common-config.yaml")
envsubst > tmp-job.yaml < restore/harbor/restore-harbor-job.yaml
./bin/ck8s ops kubectl sc create configmap -n harbor restore-harbor --from-file=restore/harbor/restore-harbor.sh
```

## Restore job Azure

### Rclone move data

If you are restoring Harbor in Azure from a bucket that was previously a rclone destination where the source was not Azure, then the path for the Harbor image data is likely wrong.
Due to an [issue with Harbor](https://github.com/distribution/distribution/issues/1247) it is storing image data with an extra `/` at the start of the path for Azure.
But it is not the same for other object storage types, so if the data was copied from e.g. S3 then it will likely be wrong now.
The following steps will create a rclone job that will move all of the harbor image data to the correct path with an extra `/`.

```bash
export S3_BUCKET=$(yq '.objectStorage.buckets.harbor' "${CK8S_CONFIG_PATH}/defaults/sc-config.yaml" )
export AZURE_ACCOUNT=$(yq '.objectStorage.azure.storageAccountName' "${CK8S_CONFIG_PATH}/common-config.yaml" )
export AZURE_KEY=$(sops -d --extract '["objectStorage"]["azure"]["storageAccountKey"]' "${CK8S_CONFIG_PATH}/secrets.yaml" )
envsubst > tmp-rclone-job.yaml < restore/harbor/harbor-rclone-azure.yaml
./bin/ck8s ops kubectl sc apply -f tmp-rclone-job.yaml
./bin/ck8s ops kubectl sc wait --for=condition=complete job -n rclone harbor-restore-rclone-move --timeout=-1s
```

Clean up:

```bash
./bin/ck8s ops kubectl sc delete -f tmp-rclone-job.yaml
rm -v tmp-rclone-job.yaml
```

### Prepare for Harbor database restore

Setup the necessary job.yaml and configmap:

```bash
envsubst > tmp-job.yaml < restore/harbor/restore-harbor-job-azure.yaml
./bin/ck8s ops kubectl sc create configmap -n harbor restore-harbor --from-file=restore/harbor/restore-harbor.sh
```

## Restore common

While restoring we need to stop all harbor pods except for the database.

```bash
./bin/ck8s ops kubectl sc scale deployment --replicas 0 -n harbor --all
```

Create the job and wait until it has completed:

```bash
./bin/ck8s ops kubectl sc apply -n harbor -f restore/harbor/network-policies-harbor.yaml
./bin/ck8s ops kubectl sc apply -n harbor -f tmp-job.yaml
./bin/ck8s ops kubectl sc wait --for=condition=complete job -n harbor restore-harbor-job --timeout=-1s
```

Restore the pods:

```bash
./bin/ck8s ops kubectl sc scale deployment --replicas 1 -n harbor --all
```

Clean up:

```bash
./bin/ck8s ops kubectl sc delete -n harbor -f restore/harbor/network-policies-harbor.yaml
./bin/ck8s ops kubectl sc delete -n harbor -f tmp-job.yaml
./bin/ck8s ops kubectl sc delete configmap -n harbor restore-harbor
rm -v tmp-job.yaml
```

### Restore to a different domain

If you are restoring harbor to a new environment with a different domain, you need to re-run the init job. First, make sure the harbor admin password is the same as in the old environment:

```bash
# Edit harbor.password
sops ${CK8S_CONFIG_PATH}/secrets.yaml
```

Then, re-run the init job:

```bash
./bin/ck8s ops kubectl sc delete job -n harbor init-harbor-job
./bin/ck8s ops helmfile sc -l app=harbor sync
```

If the new harbor is using a dex instance with a different domain compared to the dex the old harbor was using, then when users login via dex harbor will not recognize them as the same user. Harbor will have the old OIDC users in the database, but when the new ones are created at first login they will conflict with the old ones and you will get a error like `failed to create user record: user <user> or email <email> already exists`.

To fix this you need to login as an admin user (you can login with the default, non-oidc admin at the URL `/account/sign-in`) and then delete the old users in the list of users. Users can then create new users again by logging. Then you need to set their permissions again.

### Restore between swift and s3

If you are restoring Harbor from an environment that is using swift to an environment that is using s3 (or vice versa), then you need to modify some files in the object storage.

In swift Harbor stores most of the image data under `files/docker/` while in s3 it is stored under just `docker/`. This means that if you simply copy the data from swift to s3, then you need to rename all files under `files/docker/<filename>` to `docker/<filename>` or vice versa.

If you do not do this, then if you try to pull an old image you will get errors like: `Error response from daemon: manifest for <image> not found: manifest unknown: manifest unknown`
