# Restore rclone

This will guide you through restoring object storage.

> [!important]
> Ensure that all `rclone-sync` CronJobs are suspended so it cannot corrupt the backup!

## Configure

Follow the instruction that matches the scenario:

### Configure with existing main and sync

> [!tip]
> This is the only configuration needed if you want to do the reverse of an already configured `rclone-sync`.

Enable `rclone-restore` via the config:

```yaml
# file: sc-config.yaml
objectStorage:
  restore:
    enabled: true

    ## Autogenerate restore targets from sync configuration
    addTargetsFromSync: true
```

### Configure without existing main or sync

> [!tip]
> These can also be followed if you want to make overrides of already configured `rclone-sync`.

Enable `rclone-restore` via the config:

```yaml
# file: sc-config.yaml
objectStorage:
  restore:
    enabled: true
```

Specify destinations and sources you want to use, follows the same structure as `.objectStorage.type` does:

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

Specify decryption parameters if the sources are encrypted:

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

Finally specify the targets you want to restore:

```yaml
objectStorage:
  restore:
    targets:
      - destinationName: <bucket-or-container-name>
        destinationType: <object-storage-type> # azure | s3 | swift
        sourceName: <bucket-or-container-name> # optional - defaults to destination name
        sourceType: <object-storage-type> # azure | s3 | swift
```

## Apply and run

Apply:

```yaml
./bin/ck8s ops helmfile sc apply -lapp=rclone --include-transitive-needs
```

Then run the generated restore CronJobs manually:

```
$ ./bin/ck8s ops kubectl sc -n rclone get cronjob -lapp.kubernetes.io/instance=rclone-restore
<cronjobs>...

$ ./bin/ck8s ops kubectl sc -n rclone create job --from cronjob/<cronjob-name> <job-name>
```
