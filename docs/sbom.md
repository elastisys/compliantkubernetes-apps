# Welkin SBOM

The Welkin SBOM is located here: [](./sbom.json)

Follows the CycloneDX v1.6 specification (JSON): <https://cyclonedx.org/docs/1.6/json/>

## Manually modifying the SBOM

It is possible to add new JSON objects to the SBOM using `sbom add` command, e.g:

```sh
./bin/ck8s sbom add velero 6.0.0 properties '{"name": "test", "value": "test"}'
```

There is also an option to update existing values using `sbom update` command, e.g:

```sh
./bin/ck8s sbom update velero 6.0.0 properties
```

Unless the environment variable `CK8S_SKIP_VALIDATION` is set to `true`, any changes made will be validated first by the `cyclonedx` tool.
Then, as long as `CK8S_AUTO_APPROVE` is not set to `true`, a `diff` will be shown with a prompt letting the user decide if they want to proceed with the change:

```console
[ck8s] Validating CycloneDX for SBOM file
BOM validated successfully.
...
+++ /tmp/tmp.snx5KIt07a-sbom.json       2025-04-25 13:46:36.169671733 +0200
@@ -3260,6 +3260,10 @@
         {
           "name": "Elastisys evaluation",
           "value": "set-me"
+        },
+        {
+          "name": "test",
+          "value": "test"
         }
       ],
       "supplier": {
[ck8s] Changes found
[ck8s] Do you want to continue? (y/N):
```
