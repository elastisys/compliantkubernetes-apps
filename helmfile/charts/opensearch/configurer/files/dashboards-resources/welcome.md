# Welcome to Compliant Kubernetes!

## What's new

Here you can find the most relevant features and changes for the last couple of releases of Compliant Kubernetes

- Kubernetes PodSecurityPolicies have been replaced with Kubernetes Pod Security Standards and additional Gatekeeper Constraints and Mutations. **[v0.30]**
  - This should not affect user applications as the default behaviour is kept, and the new default restricted Pod Security Standard is slightly less restricted than the previous restricted PodSecurityPolicy following the upstream changes.
- Trivy Operator have replaced Starboard Operator as the online security scanning tool. **[v0.30]**
  - This includes a new Trivy Operator dashboard and the deprecation of the old Image vulnerabilities dashboard.
- Kubernetes Jobs will now have a default TTL of 7 days if unset to ensure resources are cleaned up. **[v0.30]**
- The Fluentd deployoment has changed considerably and users must ensure that their custom filters continues to work as expected. **[v0.29]**
- Static users can now be added in OpenSearch. **[v0.29]**

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

{{ if .Values.dashboard.extraTextOpensearch }}
## {{ .Values.dashboard.extraTextOpensearch }}
{{ else }}
{{ end }}

[//]: # (If you update this file, remember to also edit compliantkubernetes-apps/helmfile/charts/grafana-ops/files/welcome.md)
