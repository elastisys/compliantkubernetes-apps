### Restore Harbor
With the k8s job you can restore the database in Harbor from a backup in S3.
*Note this restore is only designed for internal harbor database and not for an external database*
The steps should be performed from the `compliantkubernetes-apps` root directory.
*Note this k8s job does not include restore from gcs.*

Before restoring the database, make sure that Harbor is installed.
It can be installed normally.

#### Env variables
Set these variables for the restore job:
```bash
export CK8S_CONFIG_PATH=<your config path>
export S3_BUCKET=$(yq4 '.objectStorage.buckets.harbor' "${CK8S_CONFIG_PATH}/defaults/sc-config.yaml" )
export S3_REGION_ENDPOINT=$(yq4 '.objectStorage.s3.regionEndpoint' "${CK8S_CONFIG_PATH}/common-config.yaml")
echo $CK8S_CONFIG_PATH
echo $S3_BUCKET
echo $S3_REGION_ENDPOINT
```

##### Optional env variables

The job will restore the latest backup.
`$SPECIFIC_BACKUP` can be used to specify which backup.
To get a list of available backups use:
```
s3cmd --config <(sops -d ${CK8S_CONFIG_PATH}/.state/s3cfg.ini) ls s3://${S3_BUCKET}/backups/
```
Then set:
```bash
export SPECIFIC_BACKUP=<backups/xxxxxxxxxx.sql.gz> # Optional
```

#### Restore

Setup the necessary job.yaml and configmap:

```bash
envsubst > tmp-job.yaml < scripts/restore/restore-harbor-job.yaml
./bin/ck8s ops kubectl sc create configmap -n harbor restore-harbor --from-file=scripts/restore/restore-harbor.sh
```

While restoring we need to stop all harbor pods except for the database.

```
./bin/ck8s ops kubectl sc scale deployment --replicas 0 -n harbor --all
```

Create the job and wait until it has completed:

```
./bin/ck8s ops kubectl sc apply -n harbor -f scripts/restore/network-policies-harbor.yaml
./bin/ck8s ops kubectl sc apply -n harbor -f tmp-job.yaml
./bin/ck8s ops kubectl sc wait --for=condition=complete job -n harbor restore-harbor-job --timeout=-1s
```

Restore the pods:

```
./bin/ck8s ops kubectl sc scale deployment --replicas 1 -n harbor --all
```

Clean up:

```
./bin/ck8s ops kubectl sc delete -n harbor -f scripts/restore/network-policies-harbor.yaml
./bin/ck8s ops kubectl sc delete -n harbor -f tmp-job.yaml
./bin/ck8s ops kubectl sc delete configmap -n harbor restore-harbor
rm -v tmp-job.yaml
```

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
