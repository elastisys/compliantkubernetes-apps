# Welcome to Compliant Kubernetes!

## What's new

Here you can find the most relevant features and changes for the last couple of releases of Compliant Kubernetes

- Thanos was upgraded to v0.34.1. **[v0.38]**
- Gatekeeper was upgraded to v3.15.1. **[v0.38]**
- A new Gatekeeper constraint was added. It will warn if the user tries to deploy a Deployment or StatefulSet with less than 2 replicas. **[v0.38]**
- Opensearch and Opensearch Dashboards were upgraded to v2.12. **[v0.37]**
- Grafana was upgraded to v10.4. **[v0.37]**
- Falco was upgraded to v0.37.1. **[v0.37]**
- A new capacity management Grafana dashboard is now available. This will give better visibility over resource usage per node groups. **[v0.37]**
- We recommend using the [ingressClassName](https://cert-manager.io/docs/configuration/acme/http01/#ingressclassname) field over the `class` field for cert-manager issuers. **[v0.37]**

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
