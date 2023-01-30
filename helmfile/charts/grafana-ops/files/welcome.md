# Welcome to Compliant Kubernetes!

## What's new

Here you can find the most relevant features and changes for the last couple of releases of Compliant Kubernetes

- Nginx ingress controller service now allows multiple annotations. **[v0.28]**
- All grafana dashboards now use the default organization timezone. **[v0.28]**
- NetworkPolicies are now automatically propagated from a parent namespace to its child namespaces. **[v0.27]**
- Made Dex tokens expiry times configurable. **[v0.27]**
- Alertmanager for the user is enabled by default. **[v0.27]**
- Admin users can now view Gatekeeper constraints. **[v0.27]**

## Public docs

In case you get lost, don't forget to check out the [public docs](https://elastisys.io/compliantkubernetes/). Here are the most common topics:

- [Getting started](https://elastisys.io/compliantkubernetes/user-guide/prepare/)
- [Maintenance expectations](https://elastisys.io/compliantkubernetes/user-guide/maintenance/)
- [Adding extra workload admins](https://elastisys.io/compliantkubernetes/user-guide/delegation/#kubernetes-api)
- [Troubleshooting](https://elastisys.io/compliantkubernetes/user-guide/troubleshooting/)
- [FAQ](https://elastisys.io/compliantkubernetes/user-guide/faq/)

## Compliant Kubernetes Version

- Apps: **{{ .Values.dashboard.ck8sVersion }}** - [Release Notes](https://elastisys.io/compliantkubernetes/release-notes/)

## Additional services:

- [grafana.{{ .Values.baseDomain }}](https://grafana.{{ .Values.baseDomain }})
- [opensearch.{{ .Values.baseDomain }}](https://opensearch.{{ .Values.baseDomain }})
- [harbor.{{ .Values.baseDomain }}](https://harbor.{{ .Values.baseDomain }})

## Did you know?

As a user of Compliant Kubernetes you can request to see your Cluster configuration (without secrets) by asking your administrator.

{{ if .Values.dashboard.extraTextGrafana }}
## {{ .Values.dashboard.extraTextGrafana }}
{{ else }}
{{ end }}

[//]: # (If you update this file, remember to also edit compliantkubernetes-apps/helmfile/charts/opensearch/configurer/files/dashboards-resources/welcome.md)
