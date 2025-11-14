# Welcome to Welkin!

## What's new

Here you can find the most relevant features and changes for the last couple of releases of Welkin

- Added self-managed Jaeger Operator support. See [Jaeger docs](https://elastisys.io/welkin/user-guide/self-managed-services/jaeger/) for more information. **[v.0.50]**
- Upgrade prometheus-blackbox-exporter chart to v11.3.1. **[v.0.50]**
- Added a new dashboard to Grafana to filter by namespace and see r/w throughput and IOPS for pods with persistent volumes.
    - Named Read and Write - Namespace (Pods with PVCs). **[v.0.50]**
- Upgrade kube-prometheus-stack chart to v77.11.1. **[v.0.50]**
- Upgrade ingress-nginx chart to v4.13.3 and app version to v1.13.3. **[v.0.50]**
- Upgraded gatekeeper to v3.20.1. **[v.0.50]**
- Added a Fluentd metric and alert which catches rejections due to mapping conflicts in OpenSearch. **[v.0.49]**
- Upgraded OpenSearch to v2.19.3. **[v.0.49]**
- Make namespace label in metric refer to resource, not exporter. **[v.0.49]**
- Added logging for failing DNS requests. **[v.0.49]**
- OpenSearch namespace is now PSS restricted. **[v.0.49]**

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
