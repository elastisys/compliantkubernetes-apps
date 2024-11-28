# Welcome to Welkin!

## What's new

Here you can find the most relevant features and changes for the last couple of releases of Welkin

- Upgraded Grafana to v11.2.3. **[v0.42]**
  - Drops support for dashboards using Angular plugins. See [here](https://grafana.com/docs/grafana/latest/developers/angular_deprecation/) for more information.
- Upgraded Falco to v0.38.2. **[v0.42]**
- Updated Grafana dashboards containing deprecated panels. **[v0.41]**
- Grafana was upgraded to v10.4.7. **[v0.41]**
- Ingress-nginx was upgraded to v1.11.2. **[v0.41]**
  - Drops support for Kubernetes v1.25 and adds support for v1.30.
- NodeLocal DNS was upgraded to v1.23.1. **[v0.41]**

## Public docs

In case you get lost, don't forget to check out the [public docs](https://elastisys.io/welkin/). Here are the most common topics:

- [Getting started](https://elastisys.io/welkin/user-guide/prepare/)
- [Maintenance expectations](https://elastisys.io/welkin/user-guide/maintenance/)
- [Adding extra workload admins](https://elastisys.io/welkin/user-guide/delegation/#kubernetes-api)
- [Troubleshooting](https://elastisys.io/welkin/user-guide/troubleshooting/)
- [FAQ](https://elastisys.io/welkin/user-guide/faq/)

## Welkin Version

- Apps: **{{ .Values.dashboard.ck8sVersion }}** - [Release Notes](https://elastisys.io/welkin/release-notes/)

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

As a user of Welkin you can request to see your Cluster configuration (without secrets) by asking your administrator.

{{ if .Values.dashboard.extraTextGrafana }}

## {{ .Values.dashboard.extraTextGrafana }}

{{ else }}
{{ end }}

[//]: # (If you update this file, remember to also edit compliantkubernetes-apps/helmfile.d/charts/opensearch/configurer/files/dashboards-resources/welcome.md)
