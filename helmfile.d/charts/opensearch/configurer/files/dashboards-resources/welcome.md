# Welcome to Welkin!

## What's new

Here you can find the most relevant features and changes for the last couple of releases of Welkin

- Added support for Cilium. **[v0.48]**
- Upgraded Harbor to v2.13.1. **[v0.48]**
- Upgraded Falco chart to v6.0.2. **[v0.48]**
- Grafana was upgraded to the new major version 12. **[v0.48]**
- Added an image signature verification Kyverno policy. This can be enabled by your Platform Administrator. **[v0.48]**
- Added options to configure session time in OpenSearch. This can be configured by your Platform Administration. **[v0.47]**

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
