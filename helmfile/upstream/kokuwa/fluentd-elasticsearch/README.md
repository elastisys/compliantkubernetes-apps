# Fluentd Elasticsearch

- Installs [Fluentd](https://www.fluentd.org/) log forwarder.

## TL;DR

```console
helm repo add kokuwa https://kokuwaio.github.io/helm-charts
helm install kokuwa/fluentd-elasticsearch
```

## Introduction

This chart bootstraps a [Fluentd](https://www.fluentd.org/) daemonset on a [Kubernetes](http://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.

It's meant to be a drop in replacement for [fluentd-gcp](https://github.com/kubernetes/kubernetes/tree/master/cluster/addons/fluentd-gcp) on [GKE](https://cloud.google.com/kubernetes-engine) which sends logs to Google [Stackdriver](https://cloud.google.com/stackdriver), but can also be used in other places where logging to [ElasticSearch](https://www.elastic.co/elasticsearch/) is required.

The used [Docker](https://docker.com) image ([Dockerfile](https://github.com/monotek/fluentd-elasticsearch)) also contains the following plugins:

- [Detect exceptions](https://github.com/GoogleCloudPlatform/fluent-plugin-detect-exceptions) (for Java multiline stacktraces)
- [Kubernetes metadata filter](https://github.com/fabric8io/fluent-plugin-kubernetes_metadata_filter)
- [Prometheus exporter](https://github.com/fluent/fluent-plugin-prometheus)
- [Systemd](https://github.com/fluent-plugin-systemd/fluent-plugin-systemd)

## Prerequisites

- Kubernetes 1.16+ with Beta APIs enabled

## Installing the Chart

To install the chart with the release name `my-release`:

```console
helm install --name my-release kokuwa/fluentd-elasticsearch
```

The command deploys fluentd-elasticsearch on the Kubernetes cluster in the default configuration. The [configuration](#configuration) section lists the parameters that can be configured during installation.

## Uninstalling the Chart

To uninstall the `my-release` deployment:

```console
helm uninstall my-release
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Configuration

The following table lists the configurable parameters of the Fluentd elasticsearch chart and their default values.

| Parameter                                               | Description                                                                       | Default                                             |
| ------------------------------------------------------- | --------------------------------------------------------------------------------- | --------------------------------------------------- |
| `affinity`                                              | Optional daemonset affinity                                                       | `{}`                                                |
| `annotations`                                           | Optional daemonset annotations                                                    | `NULL`                                              |
| `podAnnotations`                                        | Optional daemonset's pods annotations                                             | `NULL`                                              |
| `securityContext`                                       | Optional a security context for a Pod                                             | `{}`                                                |
| `configMaps.useDefaults.systemConf`                     | Use default system.conf                                                           | `true`                                              |
| `configMaps.useDefaults.containersInputConf`            | Use default containers.input.conf                                                 | `true`                                              |
| `configMaps.useDefaults.containersKeepTimeKey`          | Keep the container log timestamp as part of the log data.                         | `false`                                             |
| `configMaps.useDefaults.kubernetesMetadataFilterConfig` | Set arbitrary configuration key-value pairs for the `kubernetes_metadata` filter. | `{}`                                                |
| `configMaps.useDefaults.systemInputConf`                | Use default system.input.conf                                                     | `true`                                              |
| `configMaps.useDefaults.forwardInputConf`               | Use default forward.input.conf                                                    | `true`                                              |
| `configMaps.useDefaults.monitoringConf`                 | Use default monitoring.conf                                                       | `true`                                              |
| `configMaps.useDefaults.outputConf`                     | Use default output.conf                                                           | `true`                                              |
| `extraConfigMaps`                                       | Add additional Configmap or overwrite disabled default                            | `{}`                                                |
| `elasticsearch.auth.enabled`                            | Elasticsearch Auth enabled                                                        | `false`                                             |
| `elasticsearch.auth.user`                               | Elasticsearch Auth User                                                           | `null`                                              |
| `elasticsearch.auth.password`                           | Elasticsearch Auth Password                                                       | `null`                                              |
| `elasticsearch.auth.existingSecret.name`                | Name of secret                                                                    | `null`                                              |
| `elasticsearch.auth.existingSecret.key`                 | Key within secret containing password                                             | `null`                                              |
| `elasticsearch.setOutputHostEnvVar`                     | Use `elasticsearch.hosts` (Disable this to manually configure hosts)              | `true`                                              |
| `elasticsearch.hosts`                                   | Elasticsearch Hosts List (host and port)                                          | `["elasticsearch-client:9200"]`                     |
| `elasticsearch.includeTagKey`                           | Elasticsearch Including of Tag key                                                | `true`                                              |
| `elasticsearch.logstash.enabled`                        | Elasticsearch Logstash enabled (supersedes indexName)                             | `true`                                              |
| `elasticsearch.logstash.prefix`                         | Elasticsearch Logstash prefix                                                     | `logstash`                                          |
| `elasticsearch.logstash.prefixSeparator`                | Elasticsearch Logstash prefix separator                                           | `-`                                                 |
| `elasticsearch.logstash.dateformat`                     | Elasticsearch Logstash strftime format to generate index target index name        | `%Y.%m.%d`                                          |
| `elasticsearch.ilm.enabled`                             | Elasticsearch Index Lifecycle Management enabled                                  | `false`                                             |
| `elasticsearch.ilm.policy_id`                           | Elasticsearch ILM policy ID                                                       | `logstash-policy`                                   |
| `elasticsearch.ilm.policy`                              | Elasticsearch ILM policy to create                                                | `{}`                                                |
| `elasticsearch.ilm.policies`                            | Elasticsearch ILM policies to create, map of policy IDs and policies              | `{}`                                                |
| `elasticsearch.ilm.policy_overwrite`                    | Elastichsarch ILM policy overwrite                                                | `false`                                             |
| `elasticsearch.template.enabled`                        | Elastichsarch Template enabled                                                    | `false`                                             |
| `elasticsearch.template.name`                           | Elastichsarch Template Name                                                       | `fluentd-template`                                  |
| `elasticsearch.template.file`                           | Elasticsearch Template FileName (inside the daemonset)                            | `fluentd-template.json`                             |
| `elasticsearch.template.content`                        | Elasticsearch Template Content                                                    | _see `values.yaml`_                                 |
| `elasticsearch.template.overwrite`                      | Elasticsearch Template Overwrite (update even if it already exists)               | `false`                                             |
| `elasticsearch.template.useLegacy`                      | Use legacy Elasticsearch template                                                 | `true`                                              |
| `elasticsearch.indexName`                               | Elasticsearch Index Name                                                          | `fluentd`                                           |
| `elasticsearch.path`                                    | Elasticsearch Path                                                                | `""`                                                |
| `elasticsearch.scheme`                                  | Elasticsearch scheme setting                                                      | `http`                                              |
| `elasticsearch.sslVerify`                               | Elasticsearch Auth SSL verify                                                     | `true`                                              |
| `elasticsearch.sslVersion`                              | Elasticsearch tls version setting                                                 | `TLSv1_2`                                           |
| `elasticsearch.outputType`                              | Elasticsearch output type                                                         | `elasticsearch`                                     |
| `elasticsearch.typeName`                                | Elasticsearch type name                                                           | `_doc`                                              |
| `elasticsearch.logLevel`                                | Elasticsearch global log level                                                    | `info`                                              |
| `elasticsearch.log400Reason`                            | Elasticsearch Log 400 reason                                                      | `false`                                             |
| `elasticsearch.reconnectOnError`                        | Elasticsearch Reconnect on error                                                  | `true`                                              |
| `elasticsearch.reloadOnFailure`                         | Elasticsearch Reload on failure                                                   | `false`                                             |
| `elasticsearch.reloadConnections`                       | Elasticsearch reload connections                                                  | `false`                                             |
| `elasticsearch.requestTimeout`                          | Elasticsearch request timeout                                                     | `5s`                                                |
| `elasticsearch.suppressTypeName`                        | Elasticsearch type name suppression (for ES >= 7)                                 | `false`                                             |
| `elasticsearch.includeTimestamp`                        | Elasticsearch Include timestamp (param used only if logstash is disabled)         | `false`                                             |
| `elasticsearch.buffer.enabled`                          | Elasticsearch Buffer enabled                                                      | `true`                                              |
| `elasticsearch.buffer.chunkKeys`                        | Elasticsearch Buffer comma-separated chunk keys                                   | `""`                                                |
| `elasticsearch.buffer.type`                             | Elasticsearch Buffer type                                                         | `file`                                              |
| `elasticsearch.buffer.path`                             | Elasticsearch Buffer path                                                         | `/var/log/fluentd-buffers/kubernetes.system.buffer` |
| `elasticsearch.buffer.flushMode`                        | Elasticsearch Buffer flush mode                                                   | `interval`                                          |
| `elasticsearch.buffer.retryType`                        | Elasticsearch Buffer retry type                                                   | `exponential_backoff`                               |
| `elasticsearch.buffer.flushThreadCount`                 | Elasticsearch Buffer flush thread count                                           | `2`                                                 |
| `elasticsearch.buffer.flushInterval`                    | Elasticsearch Buffer flush interval                                               | `5s`                                                |
| `elasticsearch.buffer.retryForever`                     | Elasticsearch Buffer retry forever                                                | `true`                                              |
| `elasticsearch.buffer.retryMaxInterval`                 | Elasticsearch Buffer retry max interval                                           | `30`                                                |
| `elasticsearch.buffer.chunkLimitSize`                   | Elasticsearch Buffer chunk limit size                                             | `2M`                                                |
| `elasticsearch.buffer.totalLimitSize`                   | Elasticsearch Buffer queue limit size                                             | `512M`                                              |
| `elasticsearch.buffer.overflowAction`                   | Elasticsearch Buffer over flow action                                             | `block`                                             |
| `env`                                                   | List of env vars that are added to the fluentd pods                               | `{}`                                                |
| `fluentdArgs`                                           | Fluentd args                                                                      | `--no-supervisor -q`                                |
| `fluentdLogFormat`                                      | Fluentd output log format in the default system.conf (either "text" or "json")    | `text`                                              |
| `secret`                                                | List of env vars that are set from secrets and added to the fluentd pods          | `[]`                                                |
| `extraContainers`                                       | Add sidecar containers to each pod in the daemonset                               | `[]`                                                |
| `extraInitContainers`                                   | Add init containers to each pod in the daemonset                                  | `[]`                                                |
| `extraVolumeMounts`                                     | Mount extra volume, required to mount ssl certificates when ES has tls enabled    | `[]`                                                |
| `extraVolumes`                                          | Extra volume                                                                      | `[]`                                                |
| `fluentConfDir`                                         | Specify where to mount fluentd location                                           | `/etc/fluent/config.d`                              |
| `hostLogDir.varLog`                                     | Specify where fluentd can find var log                                            | `/var/log`                                          |
| `hostLogDir.dockerContainers`                           | Specify where fluentd can find logs for docker container                          | `/var/lib/docker/containers`                        |
| `hostLogDir.libSystemdDir`                              | Specify where fluentd can find logs for lib Systemd                               | `/usr/lib64`                                        |
| `image.repository`                                      | Image repository                                                                  | `quay.io/fluentd_elasticsearch/fluentd`             |
| `image.tag`                                             | Image tag (uses appVersion from Chart.yaml as default)                            | ``                                                  |
| `image.pullPolicy`                                      | Image pull policy                                                                 | `IfNotPresent`                                      |
| `image.pullSecrets`                                     | Image pull secrets                                                                | ``                                                  |
| `livenessProbe.enabled`                                 | Whether to enable livenessProbe                                                   | `true`                                              |
| `livenessProbe.initialDelaySeconds`                     | livenessProbe initial delay seconds                                               | `600`                                               |
| `livenessProbe.periodSeconds`                           | livenessProbe period seconds                                                      | `60`                                                |
| `livenessProbe.kind`                                    | livenessProbe kind                                                                | `Set to a Linux compatible command`                 |
| `nodeSelector`                                          | Optional daemonset nodeSelector                                                   | `{}`                                                |
| `podSecurityPolicy.annotations`                         | Specify pod annotations in the pod security policy                                | `{}`                                                |
| `podSecurityPolicy.enabled`                             | Specify if a pod security policy must be created                                  | `false`                                             |
| `priorityClassName`                                     | Optional PriorityClass for pods                                                   | `""`                                                |
| `prometheusRule.enabled`                                | Whether to enable Prometheus prometheusRule                                       | `false`                                             |
| `prometheusRule.prometheusNamespace`                    | Namespace for prometheusRule                                                      | `monitoring`                                        |
| `prometheusRule.labels`                                 | Optional labels for prometheusRule                                                | `{}`                                                |
| `rbac.create`                                           | RBAC                                                                              | `true`                                              |
| `resources.limits.cpu`                                  | CPU limit                                                                         | `100m`                                              |
| `resources.limits.memory`                               | Memory limit                                                                      | `500Mi`                                             |
| `resources.requests.cpu`                                | CPU request                                                                       | `100m`                                              |
| `resources.requests.memory`                             | Memory request                                                                    | `200Mi`                                             |
| `service`                                               | Service definition                                                                | `{}`                                                |
| `service.ports`                                         | List of service ports dict [{name:...}...]                                        | Not Set                                             |
| `service.ports[].type`                                  | Service type (ClusterIP/NodePort)                                                 | `ClusterIP`                                         |
| `service.ports[].name`                                  | One of service ports name                                                         | Not Set                                             |
| `service.ports[].port`                                  | Service port                                                                      | Not Set                                             |
| `service.ports[].nodePort`                              | NodePort port (when service.type is NodePort)                                     | Not Set                                             |
| `service.ports[].protocol`                              | Service protocol(optional, can be TCP/UDP)                                        | Not Set                                             |
| `serviceAccount.create`                                 | Specifies whether a service account should be created.                            | `true`                                              |
| `serviceAccount.name`                                   | Name of the service account.                                                      | `""`                                                |
| `serviceAccount.annotations`                            | Specify annotations in the pod service account                                    | `{}`                                                |
| `serviceMetric.enabled`                                 | Generate the metric service regardless of whether serviceMonitor is enabled.      | `false`                                             |
| `serviceMonitor.enabled`                                | Whether to enable Prometheus serviceMonitor                                       | `false`                                             |
| `serviceMonitor.port`                                   | Define on which port the ServiceMonitor should scrape                             | `24231`                                             |
| `serviceMonitor.interval`                               | Interval at which metrics should be scraped                                       | `10s`                                               |
| `serviceMonitor.path`                                   | Path for Metrics                                                                  | `/metrics`                                          |
| `serviceMonitor.labels`                                 | Optional labels for serviceMonitor                                                | `{}`                                                |
| `serviceMonitor.metricRelabelings`                      | Optional metric relabel configs to apply to samples before ingestion              | `[]`                                                |
| `serviceMonitor.relabelings`                            | Optional relabel configs to apply to samples before scraping                      | `[]`                                                |
| `serviceMonitor.jobLabel`                               | PrometheusRule jobLabel. Uses the created metrics service name if not set.        | Not Set                                             |
| `serviceMonitor.type`                                   | Optional the type of the metrics service                                          | `ClusterIP`                                         |
| `tolerations`                                           | Optional daemonset tolerations                                                    | `[]`                                                |
| `updateStrategy`                                        | Optional daemonset update strategy                                                | `type: RollingUpdate`                               |
| `extraObjects`                                          | Array of extra K8s manifests to deploy                                            | `[]`                                                |

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`. For example,

```console
helm install --name my-release kokuwa/fluentd-elasticsearch
```

Alternatively, a YAML file that specifies the values for the above parameters can be provided while installing the chart. For example,

```console
helm install --name my-release -f values.yaml kokuwa/fluentd-elasticsearch
```

## Installation

### IBM IKS

For IBM IKS path `/var/log/pods` must be mounted, otherwise only kubelet logs would be available

```yaml
extraVolumeMounts: |
    - name: pods
      mountPath: /var/log/pods
      readOnly: true

extraVolumes: |
    - name: pods
      hostPath:
        path: "/var/log/pods"
        type: Directory
```

### AWS Elasticsearch Domains

AWS Elasticsearch requires requests to upload data to be signed using [AWS Signature V4](https://docs.aws.amazon.com/general/latest/gr/signature-version-4.html). In order to support this, you can add a sidecar to the `extraContainers` configuration. An example is provided in `values.yaml`. This results in a sidecar container being deployed that proxies all requests to your Elasticsearch domain
and signs them appropriately.

## Upgrading

### From a version < 2.0.0

When you upgrade this chart you have to add the "--force" parameter to your helm upgrade command as there have been changes to the labels which makes a normal upgrade impossible.

### From a version &ge; 4.9.3 to version &ge; 5.0.0

When upgrading this chart you need to rename `livenessProbe.command` parameter to `livenessProbe.kind.exec.command` (only applicable if `livenessProbe.command` parameter was used).

### From a version &lt; 6.0.0 to version &ge; 6.0.0

When upgrading this chart  you have to perform updates for any system that
uses fluentd output from systemd logs, because now:

- field names have removed leading underscores (`_pid` becomes `pid`)
- field names from systemd are now lowercase (`PROCESS` becomes `process`)

This means any system that uses fluend output needs to be updated,
especially:

- in Kibana go to `Management > Index Patterns`, for each index click on
   `Refresh field list` icon
- fix renamed fields in other places - such as Kibana or Grafana, in items
  such as dashboards queries/vars/annotations

It is strongly suggested to set up temporarily new fluentd instance with output
to another elasticsearch index prefix to see the differences and then apply changes. The amount of fields altered can be noticeable and hard to list them all in this document.

Some dashboards can be easily fixed with sed:

```bash
cat dashboard.json | sed -e 's/_PID/pid/g'
```

Below list of most commonly used systemd fields:

```text
__MONOTONIC_TIMESTAMP
__REALTIME_TIMESTAMP
_BOOT_ID
_CAP_EFFECTIVE
_CMDLINE
_COMM
_EXE
_GID
_HOSTNAME
_MACHINE_ID
_PID
_SOURCE_REALTIME_TIMESTAMP
_SYSTEMD_CGROUP
_SYSTEMD_SLICE
_SYSTEMD_UNIT
_TRANSPORT
_UID
CODE_FILE
CODE_FUNC
CODE_FUNCTION
CODE_LINE
MESSAGE
MESSAGE_ID
NM_LOG_DOMAINS
NM_LOG_LEVEL
PRIORITY
SYSLOG_FACILITY
SYSLOG_IDENTIFIER
SYSLOG_PID
TIMESTAMP_BOOTTIME
TIMESTAMP_MONOTONIC
UNIT
```

### From a version <= 6.3.0 to version => 7.0.0

The additional plugins option has been removed as the used container image does not longer contains the build tools needed to build the plugins. Please use an own container image containing the plugins you want to use.

### From a version < 8.0.0 to version => 8.0.0

> Both `elasticsearch.host` and `elasticsearch.port` are removed in favor of `elasticsearch.hosts`

You can now [configure multiple elasticsearch hosts](https://docs.fluentd.org/output/elasticsearch#hosts-optional) as target for fluentd.

The following parameters are deprecated and will be replaced by `elasticsearch.hosts` with a default value of `["elasticsearch-client:9200"]`

```yaml
elasticsearch:
  host: elasticsearch-client
  port: 9200
```

You can use any yaml array syntax:

```yaml
elasticsearch:
  hosts: ["elasticsearch-node-1:9200", "elasticsearch-node-2:9200"]
```

```yaml
elasticsearch:
  hosts:
    - "elasticsearch-node-1:9200"
    - "elasticsearch-node-2:9200"
```

If were using `--set elasticsearch.host=elasticsearch-client --set elasticsearch.port=9200` previously, you will need to pass those values as an array as in `--set elasticsearch.host="{elasticsearch-client:9200}"`. The quotes around the curly brackets are important in order to make sure your shell passes the string through without processing it.

Note:
> If you are using the AWS Sidecar, only the first host in the array is used. [Aws-es-proxy](https://github.com/abutaha/aws-es-proxy) is limited to one endpoint.

### From a version < 8.0.0 to version => 9.0.0

In this version elasticsearch template in `output.conf` configmap was expanded to be fully configured from `values.yaml`

- decide if to add a `logstash` - toggle `logstash.enabled`
- decide if to add a `buffer` - toggle `buffer.enabled`

#### The following fields were removed from the elasticsearch block in values.yaml

- `bufferChunkLimit` in favor of `buffer.chunkLimitSize`
- `bufferQueueLimit` in favor of `buffer.queueLimitLength`
- `logstashPrefix` in favor of `logstash.enabled` and `logstash.prefix`

#### The following fields were added

- `reconnectOnError`
- `reloadOnFailure`
- `reloadConnections`
- `buffer.enabled`
- `buffer.type`
- `buffer.path`
- `buffer.flushMode`
- `buffer.retryType`
- `buffer.flushThreadCount`
- `buffer.flushInterval`
- `buffer.retryForever`
- `buffer.retryMaxInterval`
- `buffer.chunkLimitSize`
- `buffer.queueLimitLength`
- `buffer.overflowAction`

### From a version < 10.0.0 to version => 11.0.0

The chart requires now Helm >= 3.0.0 and Kubernetes >= 1.16.0

### From a version < 11.0.0 to version => 12.0.0

If you were using `awsSigningSidecar` to set up an AWS signing sidecar proxy, this has now moved to the `extraContainers` property. The example in the `values.yaml` shows the equivalent AWS signing sidecar configuration expressed now as `extraContainers`.

### From a version < 12.0.0 to version => 13.0.0

#### The following fields were changed in the elasticsearch block

- `buffer.queueLimitLength` in favor of `buffer.totalLimitSize` since `queueLimitLength` [is deprecated](https://docs.fluentd.org/configuration/buffer-section#buffering-parameters).
