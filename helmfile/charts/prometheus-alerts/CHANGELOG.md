## 2022.12.01
1. helmfile/charts/prometheus-alerts/templates/alerts/kubernetes-system-kubelet.yaml
   - ADDED - LessKubeletsThenNodes alert

## 2022.10.04
1. helmfile/charts/prometheus-alerts/templates/alerts/kubernetes-apps.yaml
   - ADDED - KubeFailedEvictedPods alert

## 2022.09.28
1. helmfile/charts/prometheus-alerts/templates/alerts/opensearch.yaml
   - ADDED - OpensearchClusterYellow, OpensearchClusterRed and $indexSizeIncreasedOverLimit

## 2022.08.17
1. helmfile/charts/prometheus-alerts/files/missing-metrics-alerts.yaml
   - MODIFIED - MetricsFromScClusterIsMissing 'for' from 5m to 15m
2. helmfile/charts/prometheus-alerts/files/thanos.yaml
   - MODIFIED - ThanosReceiveHttpRequestErrorRateHigh 'for' from 5m to 20m
3. helmfile/charts/prometheus-alerts/templates/alerts/opensearch.yaml
   - MODIFIED - OpenSearchTooFewNodesRunning 'for' from 5m to 15m

## 2022.08.10
1. fluentd.yaml
   - ADDED - new FluentdAvailableSpaceBuffer alerts

## 2022.07.07
1. predict-linear.yaml
   - ADDED - the custom CPURequest and MemoryRequest alerts for the node patterns from common-config.yaml

## 2022.06.23

1. alertmanager.rules.yaml
   - NOT UPDATED - but some alerts for alertmanager are missing
1. config-reloaders.yaml
   - NOT ADDED - should be added after the kube-prometheus-chart is upgraded
1. etcd.yaml
   - NOT ADDED - because it was not used before
1. general.rules.yaml
   - NOT UPDATED - InfoInhibitor should be added after the kube-prometheus-chart is upgraded
1. k8s.rules.yaml
   - MODIFIED - added namespace_workload_pod:kube_pod_owner:relabel
1. kube-apiserver-availability.rules.yaml
   - DELETED - because no rules are currently used
1. kube-apiserver-burnrate.rules.yaml
   - NOT ADDED - because no rules are currently used
1. kube-apiserver-histogram.rules.yaml
   - NOT ADDED - because no rules are currently used
1. kube-apiserver-slos.yaml
   - NOT ADDED - because no rules are currently used
1. kube-prometheus-general.rules.yaml
   - DELETED - because no rules are currently used
1. kube-prometheus-node-recording.rules.yaml
   - DELETED - because no rules are currently used
1. kube-scheduler.rules.yaml
   - NOT UPDATED
1. kube-state-metrics.yaml
   - OK
1. kubelet.rules.yaml
   - OK
1. kubernetes-apps.yaml
   - MODIFIED - KubeJobNotCompleted alert to match the upstream
   - ADDED - KubeContainerOOMKilled alert to catch this event
   - DELETED - KubeHpaReplicasMismatch, KubeHpaMaxedOut alerts because they are not used
1. kubernetes-resources.yaml
   - MODIFIED - KubeCPUOvercommit KubeMemoryOvercommit to match the upstream
   - DELETED - KubeCPUQuotaOvercommit, KubeMemoryQuotaOvercommit, KubeQuotaAlmostFull, KubeQuotaFullyUsed, KubeQuotaExceeded alerts because they are not used
1. kubernetes-storage.yaml
   - NOT UPDATED - the inodes alerts are missing
1. kubernetes-system-apiserver.yaml
   - MODIFIED - renamed some rules to match the upstream
1. kubernetes-system-controller-manager.yaml
   - NOT ADDED - should be added after the kube-prometheus-chart is upgraded
1. kubernetes-system-kube-proxy.yaml
   - NEW ADDED
1. kubernetes-system-kubelet.yaml
   - OK
1. kubernetes-system-scheduler.yaml
   - NOT ADDED - should be added after the kube-prometheus-chart is upgraded
1. kubernetes-system.yaml
   - MODIFIED - added namespace as grouping for KubeClientErrors
1. node-exporter.rules.yaml
   - MODIFIED - some rules to match the upstream
1. node-exporter.yaml
   - DELETED - NodeRAIDDegraded, NodeRAIDDiskFailure alerts
1. node-network.yaml
   - OK
1. alerts/opensearch.yaml
   - DELETED - OpenSearchDiskWarning because metrics do not exist for it
1. records/opensearch.yaml
   - DELETED - record elasticsearch_filesystem_data_free_percent
1. node.rules.yaml
   - ADDED - record: cluster:node_cpu:ratio_rate5m
   - DELETED - node:node_num_cpu:sum, cluster:node_cpu:ratio_rate5m because it is not used
1. prometheus-operator.yaml
   - UPDADED - PrometheusOperatorNotReady alert to include cluster
1. prometheus.yaml
   - MODIFIED - added new alerts PrometheusScrapeSampleLimitHit and PrometheusScrapeBodySizeLimitHit
