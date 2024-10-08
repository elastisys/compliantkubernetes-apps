# Restore Harbor

With the k8s job you can restore the database in Harbor from a backup in S3 or Azure blob storage.
*Note this restore is only designed for internal harbor database and not for an external database*
The steps should be performed from the `compliantkubernetes-apps` root directory.

Before restoring the database, make sure that Harbor is installed.
It can be installed normally.

## Specific backup

By default the job will restore the latest backup.
`$SPECIFIC_BACKUP` can be used to specify which backup.
To get a list of available backups use:

S3:

```bash
s3cmd --config <(sops -d ${CK8S_CONFIG_PATH}/.state/s3cfg.ini) ls s3://${S3_BUCKET}/backups/
```

Azure:

```bash
export AZURE_LOCATION=swedencentral
./scripts/azure/storage-manager.sh list-harbor-backups
```

Then set:

```bash
export SPECIFIC_BACKUP=<backups/xxxxxxxxxx.sql.gz> # Optional
```

## Restore job S3

Setup the necessary job.yaml and configmap:

```bash
export S3_BUCKET=$(yq4 '.objectStorage.buckets.harbor' "${CK8S_CONFIG_PATH}/defaults/sc-config.yaml" )
export S3_REGION_ENDPOINT=$(yq4 '.objectStorage.s3.regionEndpoint' "${CK8S_CONFIG_PATH}/common-config.yaml")
envsubst > tmp-job.yaml < restore/harbor/restore-harbor-job.yaml
./bin/ck8s ops kubectl sc create configmap -n harbor restore-harbor --from-file=restore/harbor/restore-harbor.sh
```

## Restore job Azure

Setup the necessary job.yaml and configmap:

```bash
envsubst > tmp-job.yaml < restore/harbor/restore-harbor-job-azure.yaml
./bin/ck8s ops kubectl sc create configmap -n harbor restore-harbor --from-file=restore/harbor/restore-harbor.sh
```

## Restore common

While restoring we need to stop all harbor pods except for the database.

```
./bin/ck8s ops kubectl sc scale deployment --replicas 0 -n harbor --all
```

Create the job and wait until it has completed:

```
./bin/ck8s ops kubectl sc apply -n harbor -f restore/harbor/network-policies-harbor.yaml
./bin/ck8s ops kubectl sc apply -n harbor -f tmp-job.yaml
./bin/ck8s ops kubectl sc wait --for=condition=complete job -n harbor restore-harbor-job --timeout=-1s
```

Restore the pods:

```
./bin/ck8s ops kubectl sc scale deployment --replicas 1 -n harbor --all
```

Clean up:

```
./bin/ck8s ops kubectl sc delete -n harbor -f restore/harbor/network-policies-harbor.yaml
./bin/ck8s ops kubectl sc delete -n harbor -f tmp-job.yaml
./bin/ck8s ops kubectl sc delete configmap -n harbor restore-harbor
rm -v tmp-job.yaml
```

### Restore to a different domain

If you are restoring harbor to a new environment with a different domain, you need to re-run the init job. First, make sure the harbor admin password is the same as in the old environment:

```console
# Edit harbor.password
sops ${CK8S_CONFIG_PATH}/secrets.yaml
```

Then, re-run the init job:

```console
./bin/ck8s ops kubectl sc delete job -n harbor init-harbor-job
./bin/ck8s ops helmfile sc -l app=harbor sync
```

If the new harbor is using a dex instance with a different domain compared to the dex the old harbor was using, then when users login via dex harbor will not recognize them as the same user. Harbor will have the old OIDC users in the database, but when the new ones are created at first login they will conflict with the old ones and you will get a error like `failed to create user record: user <user> or email <email> already exists`.

To fix this you need to login as an admin user (you can login with the default, non-oidc admin at the URL `/account/sign-in`) and then delete the old users in the list of users. Users can then create new users again by logging. Then you need to set their permissions again.

### Restore between swift and s3

If you are restoring Harbor from an environment that is using swift to an environment that is using s3 (or vice versa), then you need to modify some files in the object storage.

In swift Harbor stores most of the image data under `files/docker/` while in s3 it is stored under just `docker/`. This means that if you simply copy the data from swift to s3, then you need to rename all files under `files/docker/<filename>` to `docker/<filename>` or vice versa.

If you do not do this, then if you try to pull an old image you will get errors like: `Error response from daemon: manifest for <image> not found: manifest unknown: manifest unknown`
