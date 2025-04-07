
<!--
    !!! DO NOT EDIT !!!

    This file is generated from docs/sbom.yaml.
-->

# Software Bill of Materials @ v0.37.0


## Requirements

| Name | App Version | CNCF Status | License | Copyright owner | Comment |
| --- | --- | --- | --- | --- | --- |
| Ansible |  |  | LGPL-3.0-or-later | Ansible community |  |
| curl |  |  | curl | Daniel Stenberg, <daniel@haxx.se>, and many contributors |  |
| Kubernetes | 1.28.6 | graduated | Apache-2.0 | Kubernetes Authors, Linux Foundation |  |
| Helm | 3.13.3 | graduated | Apache-2.0 | Helm Authors, Linux Foundation |  |
| Helmfile | 0.162.0 |  | MIT | Rob Boll (@robboll) |  |
| Helmdiff | 3.9.4 |  | Apache-2.0 | Fabian Ruff (@databus23) |  |
| Helm Secrets | 4.5.1 |  | Apache-2.0 | Jan-Otto Kröpke (@jkroepke), Zendesk |  |
| Jq | 1.6 |  | LGPL-3.0-or-later | [Various](https://github.com/stedolan/jq/blob/master/AUTHORS) | Similar to the MIT license |
| s3cmd | 2.* |  | GPL-2.0-or-later | TGRMN Software - http://www.tgrmn.com - and contributors |  |
| sops | 3.8.1 |  | MPL-2.0 | Mozilla |  |
| yq3 | 3.4.1 |  | MIT | Various contributors |  |
| yq4 | 4.42.1 |  | MIT | Various contributors |  |
| yajsv | 1.4.1 |  | MIT | Neil Pankey <npankey@gmail.com> |  |
| pwgen | 3.4.1 |  | MIT | Theodore Ts'o tytso@alum.mit.edu |  |
| apache2 utils | 2.4.* |  | Apache-2.0 | Apache Software Foundation |  |

## Upstream Helm Charts

| Name | App Version | Chart version | CNCF Status | License | Copyright owner | Comment |
| --- | --- | --- | --- | --- | --- | --- |
| cert-manager | v1.12.8 | v1.12.8 | incubating | [Apache-2.0](https://github.com/cert-manager/cert-manager/blob/master/LICENSE) | Cert-manager Authors, Linux Foundation |  |
| common | 2.2.5 | 2.2.5 |  | [Apache-2.0](https://github.com/bitnami/charts/tree/main/bitnami/common#license) | Broadcom | From Thanos minio chart |
| common | 2.4.0 | 2.4.0 |  | [Apache-2.0](https://github.com/bitnami/charts/tree/main/bitnami/common#license) | Broadcom | From Thanos chart |
| common | 2.4.0 | 2.4.0 |  | [Apache-2.0](https://github.com/bitnami/charts/tree/main/bitnami/common#license) | Broadcom | From Fluentd chart |
| crds |  | 0.0.0 |  | Apache-2.0 | Prometheus Authors, Linux Foundation | Sub-chart of Kube-prometheus-stack |
| dex | 2.36.0 | 0.14.1 | sandbox | [Apache-2.0](https://github.com/dexidp/dex/blob/master/LICENSE) | Dex IdP Contributors, Linux Foundation |  |
| falco | 0.37.1 | 4.2.2 | incubating | [Apache-2.0](https://github.com/falcosecurity/falco/blob/master/COPYING) | Falco Authors, Linux Foundation |  |
| falcosidekick | 2.28.0 | 0.7.11 | incubating | [Apache-2.0](https://github.com/falcosecurity/falco/blob/master/COPYING) | Falco Authors, Linux Foundation |  |
| fluentd | 1.16.1 | 5.8.2 | graduated | [Apache-2.0](https://github.com/fluent/fluentd/blob/master/LICENSE) | Fluentd Project |  |
| fluentd-elasticsearch | v4.3.9 | 13.10.0 |  | [GPL-3.0-or-later](https://github.com/kokuwaio/helm-charts/blob/main/LICENSE) | [Kokuwa.io](http://kokuwa.io/) | Mostly relicenses Apache-2.0 code, 3 contributors |
| gatekeeper | v3.11.0 | 3.11.0 | graduated | [Apache-2.0](https://github.com/open-policy-agent/gatekeeper/blob/master/LICENSE) | Open Policy Agent contributors |  |
| grafana | 10.3.1 | 7.3.0 |  | [AGPL-3.0-only](https://github.com/grafana/grafana/blob/main/LICENSE) | Grafana Labs | From Kube-prometheus-stack. Not used. |
| grafana | 10.4.0 | 7.3.7 |  | [AGPL-3.0-only](https://github.com/grafana/grafana/blob/main/LICENSE) | Grafana Labs |  |
| harbor | 2.9.1 | 1.13.1 | graduated | [Apache-2.0](https://github.com/goharbor/harbor/blob/main/LICENSE) | Harbor Authors, Linux Foundation |  |
| ingress-nginx | 1.9.6 | 4.9.1 |  | [Apache-2.0](https://github.com/kubernetes/ingress-nginx/blob/main/LICENSE) | Linux Foundation |  |
| k8s-metacollector | 0.1.0 | 0.1.7 |  | [Apache-2.0](https://github.com/falcosecurity/falco/blob/master/COPYING) | Falco Authors, Linux Foundation | Deployed by falco if collectors.kubernetes.enabled |
| kube-prometheus-stack | v0.71.2 | 56.6.2 | graduated | Apache-2.0 | Prometheus Authors, Linux Foundation |  |
| kube-state-metrics | 2.10.1 | 5.16.0 |  | [Apache-2.0](https://github.com/kubernetes/kube-state-metrics/blob/main/LICENSE) | Linux Foundation |  |
| kured | 1.13.1 | 4.5.1 | sandbox | [Apache-2.0](https://github.com/kubereboot/kured/blob/main/LICENSE) | Kured authors |  |
| metrics-server | 0.6.3 | 3.10.0 |  | [Apache-2.0](https://github.com/kubernetes-sigs/metrics-server/blob/master/LICENSE) | Linux Foundation |  |
| minio | 2023.5.4 | 12.6.0 |  | [AGPL-3.0-or-later](https://github.com/minio/minio/blob/master/LICENSE) | MinIO, Inc | From Thanos helm chart |
| minio | RELEASE.2023-09-30T07-02-29Z | 5.0.14 |  | [AGPL-3.0-or-later](https://github.com/minio/minio/blob/master/LICENSE) | MinIO, Inc | S3 Storage for local dev clusters |
| opensearch | 2.12.0 | 2.18.0 |  | [Apache-2.0](https://github.com/opensearch-project/OpenSearch/blob/main/LICENSE.txt) | OpenSearch Contributors |  |
| opensearch-dashboards | 2.12.0 | 2.18.0 |  | [Apache-2.0](https://github.com/opensearch-project/OpenSearch-Dashboards/blob/main/LICENSE.txt) | OpenSearch Contributors |  |
| prometheus-blackbox-exporter | v0.24.0 | 8.2.0 |  | [Apache-2.0](https://github.com/prometheus/blackbox_exporter/blob/master/LICENSE) | [Prometheus Authors](https://github.com/prometheus/blackbox_exporter/blob/master/NOTICE) |  |
| prometheus-elasticsearch-exporter | 1.5.0 | 5.1.1 |  | [Apache-2.0](https://github.com/prometheus-community/elasticsearch_exporter/blob/master/NOTICE) | [Prometheus Authors](https://github.com/prometheus-community/elasticsearch_exporter/blob/master/NOTICE) |  |
| prometheus-node-exporter | 1.7.0 | 4.26.1 |  | [Apache-2.0](https://github.com/prometheus/node_exporter/blob/master/LICENSE) | [Prometheus Authors and others](https://github.com/prometheus/node_exporter/blob/master/NOTICE) |  |
| prometheus-windows-exporter | 0.25.1 | 0.3.0 |  | [MIT](https://github.com/prometheus-community/windows_exporter/blob/master/LICENSE#L1) | [Martin Lindhe](https://github.com/prometheus-community/windows_exporter/blob/master/LICENSE#L3C20-L3C33) | From Kube-prometheus-stack. Not used. |
| thanos | 0.31.0 | 12.6.2 | incubating | [Apache-2.0](https://github.com/thanos-io/thanos/blob/main/LICENSE) | Thanos Authors, Linux Foundation |  |
| tigera-operator | v3.26.4 | v3.26.4 |  | [Apache-2.0](https://github.com/projectcalico/calico/blob/master/LICENSE.md) | [The Kubernetes Authors](https://github.com/projectcalico/calico/blob/master/LICENSE.md) |  |
| trivy-operator | 0.17.1 | 0.19.1 |  | [Apache-2.0](https://github.com/aquasecurity/starboard/blob/main/LICENSE) | [Aqua Security Software Ltd.](https://github.com/aquasecurity/starboard/blob/main/NOTICE) |  |
| velero | 0.17.1 | 0.19.1 |  | [Apache-2.0](https://github.com/vmware-tanzu/velero/blob/main/LICENSE) | [Velero contributors](https://github.com/vmware-tanzu/velero/blob/main/cmd/velero/velero.go#L2) |  |

## Custom Helm Charts

| Name | App Version | Chart version | CNCF Status | License | Copyright owner | Comment |
| --- | --- | --- | --- | --- | --- | --- |
| autoscaling-monitoring | 1.16.0 | 0.1.0 |  |  |  |  |
| calico-accountant | 1.0 | 0.1.0 |  |  |  |  |
| calico-default-deny | 1.0 | 0.1.0 |  |  |  |  |
| calico-felix-metrics | 1.0 | 0.1.0 |  |  |  |  |
| cluster-admin-rbac | 1.0 | 0.1.0 |  |  |  |  |
| falco-psp-rbac | 0.1.0 | 0.1.0 |  |  |  |  |
| file-copier | 1.0 | 0.1.0 |  |  |  |  |
| gatekeeper-constraints | 1.0 | 0.1.0 |  |  |  |  |
| gatekeeper-metrics |  | 0.1.0 |  |  |  |  |
| gatekeeper-mutations | 1.0 | 0.1.0 |  |  |  |  |
| gatekeeper-templates | 1.0 | 0.1.0 |  |  |  |  |
| grafana-dashboards | 0.1.0 | 0.3.0 |  |  |  |  |
| grafana-label-enforcer | 1.0 | 0.1.0 |  |  |  |  |
| harbor-backup |  | 0.1.0 |  |  |  |  |
| harbor-certs | 1.0 | 0.1.0 |  |  |  |  |
| hnc | v1.1.0 | 0.1.0 |  |  |  |  |
| hnc-config | v1.1.0 | 0.1.0 |  |  |  |  |
| ingress-nginx-probe-ingress | 1.16.0 | 0.1.0 |  |  |  |  |
| init-harbor |  | 0.2.0 |  |  |  |  |
| kube-state-metrics-extra-resource-metrics |  | 0.1.0 |  |  |  |  |
| kubeapi-metrics | 1.16.0 | 0.1.0 |  |  |  |  |
| kured-secret | 1.0 | 0.1.0 |  |  |  |  |
| letsencrypt |  | 0.1.0 |  |  |  |  |
| log-manager | 0.2.0 | 0.1.0 |  |  |  |  |
| namespaces |  | 0.1.1 |  |  |  |  |
| networkpolicy-generator | 0.1.0 | 0.1.0 |  |  |  |  |
| networkpolicy-service | 1.0 | 0.2.0 |  |  |  |  |
| networkpolicy-service | 1.0 | 0.2.0 |  |  |  |  |
| networkpolicy-service | 1.0 | 0.2.0 |  |  |  |  |
| networkpolicy-workload | 1.0 | 0.2.0 |  |  |  |  |
| node-local-dns |  | 0.1.1 |  |  |  |  |
| opensearch-backup | 0.1.0 | 0.1.0 |  |  |  |  |
| opensearch-configurer | 0.1.0 | 0.1.0 |  |  |  |  |
| opensearch-curator | 0.1.0 | 0.1.0 |  |  |  |  |
| opensearch-secrets | 0.1.0 | 0.1.0 |  |  |  |  |
| opensearch-securityadmin | 0.1.0 | 0.1.0 |  |  |  |  |
| opensearch-slm | 0.1.0 | 0.1.0 |  |  |  |  |
| openstack-monitoring | 1.16.0 | 0.1.0 |  |  |  |  |
| podsecuritypolicies |  | 0.1.0 |  |  |  |  |
| prometheus-alerts | 1.0 | 0.1.1 |  |  |  |  |
| prometheus-servicemonitor | 1.0 | 0.1.1 |  |  |  |  |
| rclone-sync | 0.1.0 | 0.1.0 |  |  |  |  |
| s3-exporter | 0.5.0 | 0.1.0 |  |  |  |  |
| thanos-ingress-secret | 1.0 | 0.1.0 |  |  |  |  |
| thanos-ruler | 0.1.0 | 0.1.0 |  |  |  |  |
| user-alertmanager | 1.0 | 0.1.0 |  |  |  |  |
| user-crds | 1.0 | 0.1.0 |  |  |  |  |
| user-rbac | 1.0 | 0.1.0 |  |  |  |  |

## Container images

| Name | Tag | Helm Chart | License | Copyright Owner | Comment |
| --- | --- | --- | --- | --- | --- |
| quay.io/jetstack/cert-manager-controller | v1.12.8 | cert-manager |  |  |  |  |
| quay.io/jetstack/cert-manager-webhook | v1.12.8 | cert-manager |  |  |  |  |
| quay.io/jetstack/cert-manager-cainjector | v1.12.8 | cert-manager |  |  |  |  |
| quay.io/jetstack/cert-manager-acmesolver | v1.12.8 | cert-manager |  |  |  |  |
| quay.io/jetstack/cert-manager-ctl | v1.12.8 | cert-manager |  |  |  |  |
| ghcr.io/dexidp/dex | v2.36.0 | dex |  |  |  |  |
| docker.io/falcosecurity/falcoctl | 0.7.2 | falco |  |  |  |  |
| docker.io/falcosecurity/falco-driver-loader | 0.37.1 | falco |  |  |  |  |
| docker.io/falcosecurity/falco-no-driver | 0.37.1 | falco |  |  |  |  |
| docker.io/falcosecurity/falcosidekick | 2.28.0 | falcosidekick |  |  |  |  |
| docker.io/bitnami/fluentd | 1.16.1-debian-11-r12 | fluentd |  |  |  |  |
| ghcr.io/elastisys/fluentd | v4.3.9-ck8s1 | fluentd-elasticsearch |  |  |  |  |
| docker.io/openpolicyagent/gatekeeper | v3.11.0 | gatekeeper |  |  |  |  |
| docker.io/grafana/grafana | 10.3.1 | grafana |  |  |  |  |
| docker.io/curlimages/curl | 7.85.0 | grafana |  |  |  |  |
| docker.io/library/busybox | 1.31.1 | grafana |  |  |  |  |
| quay.io/kiwigrid/k8s-sidecar | 1.25.2 | grafana |  |  |  |  |
| docker.io/grafana/grafana-image-renderer | latest | grafana |  |  |  |  |
| docker.io/grafana/grafana | 10.4.0 | grafana |  |  |  |  |
| quay.io/kiwigrid/k8s-sidecar | 1.26.1 | grafana |  |  |  |  |
| docker.io/goharbor/harbor-core | v2.9.1 | harbor |  |  |  |  |
| docker.io/goharbor/harbor-db | v2.9.1 | harbor |  |  |  |  |
| docker.io/goharbor/harbor-exporter | v2.9.1 | harbor |  |  |  |  |
| docker.io/goharbor/harbor-jobservice | v2.9.1 | harbor |  |  |  |  |
| docker.io/goharbor/harbor-portal | v2.9.1 | harbor |  |  |  |  |
| docker.io/goharbor/redis-photon | v2.9.1 | harbor |  |  |  |  |
| docker.io/goharbor/registry-photon | v2.9.1 | harbor |  |  |  |  |
| docker.io/goharbor/harbor-registryctl | v2.9.1 | harbor |  |  |  |  |
| docker.io/goharbor/trivy-adapter-photon | v2.9.1 | harbor |  |  |  |  |
| registry.k8s.io/ingress-nginx/controller-chroot | v1.9.6 | ingress-nginx |  |  |  |  |
| registry.k8s.io/defaultbackend-amd64 | 1.5 | ingress-nginx |  |  |  |  |
| registry.k8s.io/ingress-nginx/kube-webhook-certgen | v20231226-1a7112e06 | ingress-nginx |  |  |  |  |
| docker.io/falcosecurity/k8s-metacollector | 0.1.0 | k8s-metalcollector |  |  |  |  |
| quay.io/prometheus-operator/admission-webhook | v0.71.2 | kube-prometheus-stack |  |  |  |  |
| registry.k8s.io/ingress-nginx/kube-webhook-certgen | v20221220-controller-v1.5.1-58-g787ea74b6 | kube-prometheus-stack |  |  |  |  |
| quay.io/prometheus-operator/prometheus-operator | v0.71.2 | kube-prometheus-stack |  |  |  |  |
| quay.io/prometheus-operator/prometheus-config-reloader | v0.71.2 | kube-prometheus-stack<br/>user-alertmanager |  |  |  |  |
| quay.io/prometheus/prometheus | v2.49.1 | kube-prometheus-stack |  |  |  |  |
| quay.io/prometheus/alertmanager | v0.26.0 | kube-prometheus-stack<br/>user-alertmanager |  |  |  |  |
| registry.k8s.io/kube-state-metrics/kube-state-metrics | v2.10.1 | kube-state-metrics |  |  |  |  |
| ghcr.io/kubereboot/kured | 1.13.1 | kured |  |  |  |  |
| registry.k8s.io/metrics-server/metrics-server | v0.6.3 | metrics-server |  |  |  |  |
| docker.io/bitnami/minio | 2023.5.4-debian-11-r1 | minio |  |  |  |  |
| quay.io/minio/minio | RELEASE.2023-09-30T07-02-29Z | minio |  |  |  |  |
| quay.io/minio/mc | RELEASE.2023-09-29T16-41-22Z | minio |  |  |  |  |
| docker.io/opensearchproject/opensearch | 2.12.0 | opensearch |  |  |  |  |
| ghcr.io/elastisys/curl-jq | 1.0.0 | opensearch<br/>init-harbor<br/>opensearch-configurer<br/>opensearch-backup |  |  |  |  |
| docker.io/opensearchproject/opensearch-dashboards | 2.12.0 | opensearch-dashboards |  |  |  |  |
| quay.io/prometheus/blackbox-exporter | v0.24.0 | prometheus-blackbox-exporter |  |  |  |  |
| quay.io/prometheuscommunity/elasticsearch-exporter | v1.5.0 | prometheus-elasticsearch-exporter |  |  |  |  |
| quay.io/prometheus/node-exporter | v1.7.0 | prometheus-node-exporter |  |  |  |  |
| ghcr.io/prometheus-community/windows-exporter | 0.25.1 | prometheus-windows-exporter |  |  |  |  |
| docker.io/bitnami/thanos | 0.31.0-scratch-r5 | thanos |  |  |  |  |
| quay.io/prometheus-operator/prometheus-config-reloader | v0.50.0 | thanos |  |  |  |  |
| docker.io/calico/ctl | v3.26.4 | tigera-operator |  |  |  |  |
| quay.io/tigera/operator | v1.30.9 | tigera-operator |  |  |  |  |
| ghcr.io/aquasecurity/trivy-operator | 0.17.1 | trivy-operator |  |  |  |  |
| ghcr.io/aquasecurity/trivy | 0.47.0 | trivy-operator |  |  |  |  |
| docker.io/velero/velero | v1.11.1 | velero |  |  |  |  |
| ghcr.io/elastisys/calico-accountant | 0.1.6 | calico-accountant |  |  |  |  |
| docker.io/busybox | 1.36 | file-copier |  |  |  |  |
| docker.io/bitnami/kubectl | 1.25 | gatekeeper-templates |  |  |  |  |
| quay.io/prometheuscommunity/prom-label-proxy | master | grafana-label-enforcer |  |  |  |  |
| ghcr.io/elastisys/backup-postgres | 1.3.0 | harbor-backup |  |  |  |  |
| ghcr.io/elastisys/hnc-manager | v1.1.0 | hnc |  |  |  |  |
| ghcr.io/elastisys/compliantkubernetes-apps-log-manager | 0.2.0 | log-manager |  |  |  |  |
| registry.k8s.io/dns/k8s-dns-node-cache | 1.22.20 | node-local-dns |  |  |  |  |
| ghcr.io/elastisys/bitnami/elasticsearch-curator | 5.8.4-debian-10-r235 | opensearch-curator |  |  |  |  |
| ghcr.io/elastisys/rclone-sync | 1.63.0 | rclone-sync |  |  |  |  |
| ghcr.io/elastisys/s3-exporter | 0.5.0 | s3-exporter |  |  |  |  |
