# Welcome to Compliant Kubernetes!

## What's new

Here you can find the most relevant features and changes for the last couple of releases of Compliant Kubernetes

- Opensearch and Opensearch Dashboards were upgraded to v2.12. **[v0.37]**
- Grafana was upgraded to v10.4. **[v0.37]**
- Falco was upgraded to v0.37.1. **[v0.37]**
- A new capacity management Grafana dashboard is now available. This will give better visibility over resource usage per node groups. **[v0.37]**
- We recommend using the [ingressClassName](https://cert-manager.io/docs/configuration/acme/http01/#ingressclassname) field over the `class` field for cert-manager issuers. **[v0.37]**
- A probe ingress is added to monitor services that are not responding successfully. **[v0.36]**
- Velero was upgraded to v1.11.1. **[v0.36]**
- The CIS Kubernetes Benchmark is removed since we migrated to trivy operator. **[v0.36]**
- Harbor was upgraded to v2.9.1. As part of this upgrade, Notary V1 is removed. **[v0.35]**
- Chroot is enabled by default for ingress-nginx controller, to improve security and limit NGINX inside the controller container from having access to list cluster-wide secrets **[v0.35]**
- Application developers can now self manage CRDs for Kafka **[v0.35]**

## Public docs

In case you get lost, don't forget to check out the [public docs](https://elastisys.io/compliantkubernetes/). Here are the most common topics:

- [Getting started](https://elastisys.io/compliantkubernetes/user-guide/prepare/)
- [Maintenance expectations](https://elastisys.io/compliantkubernetes/user-guide/maintenance/)
- [Adding extra workload admins](https://elastisys.io/compliantkubernetes/user-guide/delegation/#kubernetes-api)
- [Troubleshooting](https://elastisys.io/compliantkubernetes/user-guide/troubleshooting/)
- [FAQ](https://elastisys.io/compliantkubernetes/user-guide/faq/)

## Compliant Kubernetes Version

- Apps: **{{ .Values.dashboard.ck8sVersion }}** - [Release Notes](https://elastisys.io/compliantkubernetes/release-notes/)

{{ $baseDomain := .Values.baseDomain }}
{{ range .Values.dashboard.extraVersions }}

- {{ if .url }}[{{ .name }}]({{ .url }}){{ else if .subdomain }}[{{ .name }}](https://{{ .subdomain }}.{{ $baseDomain }}/){{ else }}{{ .name }}{{ end }}{{ if .version }}: **{{ .version }}**{{ end }}{{ if .releasenotes }} - [Release Notes]({{ .releasenotes }}){{ end }}

{{ end }}

## Web Portals

- [grafana.{{ .Values.baseDomain }}](https://grafana.{{ .Values.baseDomain }})
{{ if .Values.dashboard.opensearch }}
- [opensearch.{{ .Values.baseDomain }}](https://opensearch.{{ .Values.baseDomain }})
{{ end }}
- [harbor.{{ .Values.baseDomain }}](https://harbor.{{ .Values.baseDomain }})

## Did you know?

As a user of Compliant Kubernetes you can request to see your Cluster configuration (without secrets) by asking your administrator.

{{ if .Values.dashboard.extraTextGrafana }}

## {{ .Values.dashboard.extraTextGrafana }}

{{ else }}
{{ end }}

[//]: # (If you update this file, remember to also edit compliantkubernetes-apps/helmfile.d/charts/opensearch/configurer/files/dashboards-resources/welcome.md)
