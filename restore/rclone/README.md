# Restore rclone

This will guide you through restoring object storage if your primary object storage is corrupted or unavailable.
Additionally it allows for data to be restored with point in time if using versioning (currently only supported for S3) in your off-site backup.

> [!important]
> Ensure that all `rclone-sync` CronJobs are suspended or removed so they cannot corrupt the backup!
>
> ```sh
> ./bin/ck8s ops helmfile sc -lname=rclone-sync destroy
> ```
>
> Ensure that all `rclone-sync` Jobs are terminated so they cannot interfere with the restore!
>
> ```sh
> ./bin/ck8s ops kubectl sc -n rclone delete jobs -lapp.kubernetes.io/instance=rclone-sync
> ```
>
> When `rclone-restore` is enabled via the config the CronJobs will be removed automatically.

## Configure

Follow the instruction that matches the scenario:

### Configure with existing main and sync

> [!tip]
> This is the only configuration needed if you want to do the reverse of an already configured `rclone-sync`.
>
> _Restoring all object storage data from the off-site backup._

Enable `rclone-restore` via the config:

```yaml
# file: sc-config.yaml
objectStorage:
  restore:
    enabled: true

    ## Autogenerate restore targets from sync configuration
    addTargetsFromSync: true
```

If your off-site backup uses S3 and versioning you may restore from a set point in time by setting a timestamp:

```yaml
# file: sc-config.yaml
objectStorage:
  restore:
    ## See https://rclone.org/docs/#time-option for the format
    timestamp: ""
```

> [!important]
> With this configuration `rclone-restore` **will overwrite the data stored in main object storage**!

### Configure without existing main or sync

> [!tip]
> These can also be followed if you want to make overrides of already configured `rclone-sync`.
>
> _Restoring select object storage data from the off-site backup with possible overrides._

Enable `rclone-restore` via the config:

```yaml
# file: sc-config.yaml
objectStorage:
  restore:
    enabled: true
```

Specify destinations and sources you want to use, follows the same structure as `.objectStorage.type` does ([config schema](https://elastisys.io/welkin/operator-manual/schema/config-properties-object-storage-config-properties-rclone-restore-config)) ([secrets schema](https://elastisys.io/welkin/operator-manual/schema/secrets-properties-object-storage-secrets-properties-rclone-restore-secrets/)):

> [!warning]
> [Known issue](https://github.com/elastisys/compliantkubernetes-apps/issues/2303): Restoring Harbor from S3 to Azure does not currently work.

```yaml
# file: sc-config.yaml
objectStorage:
  restore:
    destinations:
      azure:
        ...
      s3:
        ...
      swift:
        ...

    sources:
      azure:
        ...
      s3:
        ...
      swift:
        ...
```

Specify decryption parameters if the sources are encrypted ([config schema](https://elastisys.io/welkin/operator-manual/schema/config-properties-object-storage-config-properties-rclone-sync-config-properties-rclone-crypt/)) ([secrets schema](https://elastisys.io/welkin/operator-manual/schema/secrets-properties-object-storage-secrets-properties-rclone-sync-secrets-properties-rclone-crypt-secrets/)):

```yaml
objectStorage:
  restore:
    decrypt:
      enabled: true

      passwordObscured: <password-obscured-with-rclone-obscure>
      saltObscured: <salt-obscured-with-rclone-obscure>

      fileName: false # decrypt file names
      directoryName: false # decrypt directory names
```

Finally specify the targets you want to restore ([config schema](https://elastisys.io/welkin/operator-manual/schema/config-properties-object-storage-config-properties-rclone-restore-config-properties-rclone-restore-targets-rclone-restore-target/)):

```yaml
objectStorage:
  restore:
    targets:
      - destinationName: <bucket-or-container-name>
        destinationType: <object-storage-type> # azure | s3 | swift
        sourceName: <bucket-or-container-name> # optional - defaults to destination name
        sourceType: <object-storage-type> # azure | s3 | swift
```

If your off-site backup uses S3 and versioning you may restore from a set point in time by setting a timestamp:

```yaml
# file: sc-config.yaml
objectStorage:
  restore:
    ## See https://rclone.org/docs/#time-option for the format
    timestamp: ""
```

> [!important]
> With this configuration `rclone-sync` **_may_ overwrite the data stored in main object storage** depending on your configuration!

## Apply and run

Apply `app=rclone` with helmfile:

```sh
./bin/ck8s ops helmfile sc apply -lapp=rclone --include-transitive-needs
```

_This will remove `rclone-sync` if you did not do that before._

Then run the generated restore CronJobs manually:

```console
for cronjob in $(./bin/ck8s ops kubectl sc -n rclone get cronjobs -lapp.kubernetes.io/instance=rclone-restore -oname); do
  ./bin/ck8s ops kubectl sc -n rclone create job --from "${cronjob}" "${cronjob/#cronjob.batch\/}"
done

./bin/ck8s ops kubectl sc -n rclone get pods -lapp.kubernetes.io/instance=rclone-restore -w
```

Then wait for completion and verify the logs of the `rclone-restore` Pods to ensure that they managed to restore all data.

## Continue restore

After the restore following:

- [the "Configure with existing main and sync" instructions](#configure-with-existing-main-and-sync) _no reconfiguration is required_ to restore other services.
- [the "Configure without existing main or sync" instructions](#configure-without-existing-main-or-sync) **reconfiguration may be required** to restore other services depending on your configuration.

## Continue sync

> [!important]
> Ensure you have restored required data from the off-site backup before re-enabling `rclone-sync`!

To re-enable `rclone-sync` update your configuration to match if the object storage or targets have changed.

Disable `rclone-restore` via the config:

```yaml
# file: sc-config.yaml
objectStorage:
  restore:
    enabled: false
```

Apply `app=rclone` with helmfile:

```sh
./bin/ck8s ops helmfile sc apply -lapp=rclone --include-transitive-needs
```
