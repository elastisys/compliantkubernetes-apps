# Welkin SBOM

The Welkin SBOM is located as a JSON file here: [sbom.json](./sbom.json)

Follows the CycloneDX v1.6 specification (JSON): <https://cyclonedx.org/docs/1.6/json/>

## Updating charts and SBOM components

When updating Helm charts, the SBOM should be updated to reflect these changes to keep it up to date.
There are pre-commit hooks in place to ensure maintainers remembers to update the SBOM.
The SBOM hooks should include the Chart/SBOM component location which is then used to run the `sbom update` command with.
To run the command, `GITHUB_TOKEN` environment variable needs to be set, as the command does requests to the GitHub API to retrieve licenses for components.
More on authenticating to the GitHub API using tokens and how to create them can be found at [docs.github.com](https://docs.github.com/en/rest/authentication/authenticating-to-the-rest-api?apiVersion=2022-11-28).
The following example shows the output of the pre-commit hook if it fails, which includes the command you should run to properly update the SBOM:

```console
$ pre-commit run --all-files sbom-diff
SBOM diff................................................................Failed
- hook id: sbom-diff
- exit code: 1

[ck8s] Chart version "4.12.3" does not match SBOM "4.12.1"
[ck8s] Run the following to update the SBOM:
[ck8s] ./scripts/sbom/sbom.bash update helmfile.d/upstream/kubernetes-ingress-nginx/ingress-nginx
```

During releases, the whole SBOM should be updated in case any licenses have changed, or in the case that the SBOM has not been properly updated during updates to the main branch.
This is done by running the `sbom generate` command which goes through all charts found in [`helmfile.d`](../helmfile.d/) folder and retrieves information automatically upstream, provided that the `GITHUB_TOKEN` environment variable is set.

## Manually modifying the SBOM

It is possible to add new JSON objects to the SBOM using `sbom add` command, e.g:

```sh
./scripts/sbom/sbom.bash add helmfile.d/upstream/vmware-tanzu/velero properties "foo" "bar"
```

There is also an option to edit existing values using `sbom edit` command, e.g:

```sh
./scripts/sbom/sbom.bash edit helmfile.d/upstream/vmware-tanzu/velero properties
```

Unless the environment variable `CK8S_SKIP_VALIDATION` is set to `true`, any changes made will be validated first by the `cyclonedx` tool.
Then, as long as `CK8S_AUTO_APPROVE` is not set to `true`, a `diff` will be shown with a prompt letting the user decide if they want to proceed with the change:

```console
[ck8s] Validating CycloneDX for SBOM file
BOM validated successfully.
...
@@ -3260,6 +3260,10 @@
         {
           "name": "Elastisys evaluation",
           "value": "set-me"
+        },
+        {
+          "name": "foo",
+          "value": "bar"
         }
       ],
       "supplier": {
[ck8s] Changes found
[ck8s] Do you want to continue? (y/N):
```

## Retrieving information from the SBOM

The SBOM script includes some useful `get` commands that can be used to retrieve lists of charts, containers, locations, or to describe a particular component.

### Getting unset required fields

Some fields currently needs to be updated manually in the SBOM, these includes the `Elastisys evaluation` and `supplier`, but also some fields like `licenses` might not be retrieved automatically through the `generate` or `update` commands due to the charts not providing sufficient information.
To get a list of the components that are missing such fields, it is possible to run the following:

```sh
./scripts/sbom/sbom.bash get-unset
```

There is also a pre-commit hook that will fail if any such field is not configured or is missing.

### Listing charts/components

To list all charts, or components, of the SBOM you can run the following:

```sh
./scripts/sbom/sbom.bash get-charts
```

This will output each chart by name, version and location in `ndjson` format, e.g:

```json
{"name":"velero","version":"6.0.0","location":"helmfile.d/upstream/vmware-tanzu/velero"}
```

### Listing containers

To list all containers part of the SBOM you can run the following:

```sh
./scripts/sbom/sbom.bash get-containers
```

This will output each container image name and version in `ndjson` format, e.g:

```json
{"name":"velero/velero","version":"v1.13.0"}
```
