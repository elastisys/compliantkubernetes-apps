# Modules

``` shell
crossplane xpkg init dex configuration-template
```

Edit `crossplane.yaml` and fill in metadata and dependencies etc.

Generate XRD:

```shell
./hack/definition-gen.bash metrics-server
```

Publish a Configuration package:

```shell
./hack/push-package.bash metrics-server v0.0.1
```

Verify that there are no diffs between the existing release and the module payload:

```shell
./hack/test.bash diff-release service_cluster opensearch module-opensearch opensearch-master
```

While developing you might want to diff against the template on main:

```shell
./hack/test.bash diff-main-template service_cluster opensearch module-opensearch opensearch-data
```

To validate the XR against the XRD:

```shell
./hack/test.bash validate service_cluster opensearch module-opensearch
```

Diff against main and validate:

```shell
./hack/test.bash dev service_cluster opensearch module-opensearch opensearch-client
```
