# Welcome to Compliant Kubernetes!

## What's new

Here you can find the most relevant features and changes for the last couple of releases of Compliant Kubernetes

- Added alerts for Harbor. **[v0.33]**
- Removed the deprecated grafana dashboard "Image vulnerabilities". **[v0.33]**
- Added some default annotations for Harbor that will fix issues with not being able to upload larger images **[v0.32]**

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
- [opensearch.{{ .Values.baseDomain }}](https://opensearch.{{ .Values.baseDomain }})
- [harbor.{{ .Values.baseDomain }}](https://harbor.{{ .Values.baseDomain }})

## Did you know?

As a user of Compliant Kubernetes you can request to see your Cluster configuration (without secrets) by asking your administrator.

{{ if .Values.dashboard.extraTextGrafana }}

## {{ .Values.dashboard.extraTextGrafana }}

{{ else }}
{{ end }}

[//]: # (If you update this file, remember to also edit compliantkubernetes-apps/helmfile/charts/opensearch/configurer/files/dashboards-resources/welcome.md)
