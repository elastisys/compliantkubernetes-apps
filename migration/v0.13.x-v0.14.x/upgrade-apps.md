# Upgrade v0.13.x to v0.14.0

1. Checkout the new release: `git checkout v0.14.0`

1. Run init to get new defaults: `./bin/ck8s init`.
   This will add default values for the S3-exporter.
   Please modify them if needed.

1. If you have `objectStorage.type == s3`, please add `objectstorage.s3.forcePathStyle` to `sc-config.yaml`.
   The value should be `true` if you have `fluentd.forwarder.useRegionEndpoint == true`.
   Generally it should be `false` when using AWS and Exoscale S3 and `true` otherwise.

1. Apply the rest: `./bin/ck8s apply sc` and `./bin/ck8s apply wc`.
