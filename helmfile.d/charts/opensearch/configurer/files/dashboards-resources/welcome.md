# Welcome to Compliant Kubernetes!

## What's new

Here you can find the most relevant features and changes for the last couple of releases of Compliant Kubernetes

- Harbor was upgraded to v2.9.1. As part of this upgrade, Notary V1 is removed. **[v0.35]**
- Chroot for ingress-nginx is enabled by default. **[v0.35]**
- Application developers can now self manage CRDs for Kafka **[v0.35]**
- Dashboard for visualizing how spread-out pods are across nodes. **[v0.34]**
- Application developers can now self manage CRDs for MongoDB, SealedSecrets and Flux **[v0.34]**
- Upgrade Ingress-NGINX controller to 1.8.4 and chart to 4.7.3 **[v0.34]**
- Upgrade HNC and expose opt-in propagation. **[v0.34]**

## Public docs

In case you get lost, don't forget to check out the [public docs](https://elastisys.io/compliantkubernetes/). Here are the most common topics:

- [Getting started](https://elastisys.io/compliantkubernetes/user-guide/prepare/)
- [Maintenance expectations](https://elastisys.io/compliantkubernetes/user-guide/maintenance/)
- [Adding extra workload admins](https://elastisys.io/compliantkubernetes/user-guide/delegation/#kubernetes-api)
- [Troubleshooting](https://elastisys.io/compliantkubernetes/user-guide/troubleshooting/)
- [FAQ](https://elastisys.io/compliantkubernetes/user-guide/faq/)

## Compliant Kubernetes Version

- Apps: **{{ .Values.dashboard.ck8sVersion }}** - [Release Notes](https://elastisys.io/compliantkubernetes/release-notes/)

## Web Portals

- [grafana.{{ .Values.baseDomain }}](https://grafana.{{ .Values.baseDomain }})
- [opensearch.{{ .Values.baseDomain }}](https://opensearch.{{ .Values.baseDomain }})
- [harbor.{{ .Values.baseDomain }}](https://harbor.{{ .Values.baseDomain }})

## Did you know?

As a user of Compliant Kubernetes you can request to see your Cluster configuration (without secrets) by asking your administrator.

{{ if .Values.dashboard.extraTextOpensearch }}
## {{ .Values.dashboard.extraTextOpensearch }}
{{ else }}
{{ end }}

[//]: # (If you update this file, remember to also edit compliantkubernetes-apps/helmfile.d/charts/grafana-dashboards/files/welcome.md)
