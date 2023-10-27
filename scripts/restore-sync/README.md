# Restore off-site backups

This will guide you through restoring a bucket from an off-site backup.

> Make sure that the `rclone-sync` CronJobs are suspended so it won't destroy the off-site backup!

## Extract rclone config

- If you still have `rclone-sync` deployed then you can use its config:

  ```bash
  export RCLONE_CONFIG="rclone-sync-config"
  ```

- Else have sync configured, template the `rclone-sync-config` secret, and apply:

  ```bash
  ./bin/ck8s ops helmfile sc -l app=rclone-sync template | \
    yq4 '[.] // []' - | yq4 '.[] | select(.kind == "Secret")' - | \
    yq4 '.metadata.name = "rclone-sync-restore-config"' - | \
    ./bin/ck8s ops kubectl sc -n kube-system apply -f -

  export RCLONE_CONFIG="rclone-sync-restore-config"
  ```

## Run

The destination S3 service must be set with a prefix when setting the destination bucket for the restore.
Setting the prefix `default` will restore into the main S3 service, and `backup` will restore into the off-site service.

The destination bucket will be created automatically if it does not exists already.

### Encrypted

With `<encrypted-bucket>` being the name of the encrypted bucket to restore, `<restored-bucket>` being the bucket to restore to, and `<prefix>` being the destination S3 service (`default` or `backup`):

```bash
SOURCE="encrypt-<encrypted-bucket>:" DESTINATION="<prefix>:<restored-bucket>" envsubst < ./scripts/restore-sync/template.job.yaml | ./bin/ck8s ops kubectl sc apply -f -
```

> Important here that the value set for `SOURCE` is prefixed with `encrypt-` and ends with `:`!
>
> Make sure that the two buckets have separate names when restoring into the off-site S3 service!

### Encrypted and Object lock enabled

With `<encrypted-bucket>` being the name of the encrypted and object locked bucket to restore, `<restored-bucket>` being the bucket to restore to, and `<prefix>` being the destination S3 service (`default` or `backup`):

```bash
SOURCE="encrypt-<encrypted-bucket>,version_at="<version-timestamp>":" DESTINATION="<prefix>:<restored-bucket>" envsubst < ./scripts/restore-sync/template.job.yaml | ./bin/ck8s ops kubectl sc apply -f -
```

> Important here that the value set for `SOURCE` is prefixed with `encrypt-` and ends with `:`!
>
> Make sure that the two buckets have separate names when restoring into the off-site S3 service!
>
> You can find the `version-timestamp` using `aws --endpoint https://<s3-endpoint-url> s3api list-object-versions --bucket <encrypted-bucket>`

### Unencrypted

In the event that the off-site backup is unencrypted but still needs to be restored into the main S3 service.

With `<backup-bucket>` being the unencrypted bucket to restore, and `<restored-bucket>` being the bucket to restore to:

```bash
SOURCE="backup:<backup-bucket>" DESTINATION="default:<restored-bucket>" envsubst < ./scripts/restore-sync-encrypt/template.job.yaml | ./bin/ck8s ops kubectl sc apply -f -
```
