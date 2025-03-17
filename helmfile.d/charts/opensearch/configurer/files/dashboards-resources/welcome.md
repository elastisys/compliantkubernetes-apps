# Welcome to Welkin!

## What's new

Here you can find the most relevant features and changes for the last couple of releases of Welkin

- Upgraded Thanos chart to v15.13.1. **[v0.45]**
- Added NVIDIA GPU driver support for Ubuntu 24.04. **[v0.45]**
- Added NVIDIA GPU operator to Welkin. **[v0.44]**
- Upgraded kube-prometheus-stack to 67.11.0. **[v0.44]**
- Upgraded Falco to v0.40.0. **[v0.44]**

## Public docs

In case you get lost, don't forget to check out the [public docs](https://elastisys.io/welkin/). Here are the most common topics:

- [Getting started](https://elastisys.io/welkin/user-guide/prepare/)
- [Maintenance expectations](https://elastisys.io/welkin/user-guide/maintenance/)
- [Adding extra workload admins](https://elastisys.io/welkin/user-guide/delegation/#kubernetes-api)
- [Troubleshooting](https://elastisys.io/welkin/user-guide/troubleshooting/)
- [FAQ](https://elastisys.io/welkin/user-guide/faq/)

## Welkin Version

- Apps: **{{ .Values.dashboard.ck8sVersion }}** - [Release Notes](https://elastisys.io/welkin/release-notes/)

## Web Portals

- [grafana.{{ .Values.baseDomain }}](https://grafana.{{ .Values.baseDomain }})
- [opensearch.{{ .Values.baseDomain }}](https://opensearch.{{ .Values.baseDomain }})
- [harbor.{{ .Values.baseDomain }}](https://harbor.{{ .Values.baseDomain }})

## Did you know?

As a user of Welkin you can request to see your Cluster configuration (without secrets) by asking your administrator.

{{ if .Values.dashboard.extraTextOpensearch }}

## {{ .Values.dashboard.extraTextOpensearch }}

{{ else }}
{{ end }}

[//]: # (If you update this file, remember to also edit compliantkubernetes-apps/helmfile.d/charts/grafana-dashboards/files/welcome.md)
