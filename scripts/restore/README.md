### Restore Harbor
With the k8s job you can restore the database in Harbor from a backup in S3.
The steps should be preformed from the `compliantkubernetes-apps` root directory.
*Note this k8s job does not include restore from gcs.*

Before restoring the database, make sure that Harbor is installed.
It can be installed normally.

#### Env variables
Set these variables for the restore job:
```bash
export CK8S_CONFIG_PATH=<your config path>
export S3_BUCKET=$(yq read "${CK8S_CONFIG_PATH}/sc-config.yaml" objectStorage.buckets.harbor)
export S3_REGION_ENDPOINT=$(yq read "${CK8S_CONFIG_PATH}/sc-config.yaml" objectStorage.s3.regionEndpoint)
```

##### Optional env variables

The job will restore the latest backup.
`$SPECIFIC_BACKUP` can be used to specify which backup.
To get a list of available backups use:
```
aws s3 ls ${S3_BUCKET}"/backups" --recursive --endpoint-url=${S3_REGION_ENDPOINT}
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
./bin/ck8s ops kubectl sc apply -n harbor -f tmp-job.yaml
./bin/ck8s ops kubectl sc wait --for=condition=complete job -n harbor restore-harbor-job --timeout=-1s
```

Restore the pods:

```
./bin/ck8s ops kubectl sc scale deployment --replicas 1 -n harbor --all
```

Clean up:

```
./bin/ck8s ops kubectl sc delete -n harbor -f tmp-job.yaml
./bin/ck8s ops kubectl sc delete configmap -n harbor restore-harbor
rm -v tmp-job.yaml
```
