{{/* Render exceptions */}}
{{- define "podsecuritypolicies.renderExceptions" -}}
{{- range $exception := . }}
{{- range $key, $value := $exception }}
- key: {{ $key }}
  operator: NotIn
  values:
    - {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/* Render match exceptions */}}
{{- define "podsecuritypolicies.renderMatchExceptions" -}}
scope: Namespaced
kinds:
  - apiGroups: [""]
    kinds: ["Pod"]
namespaces:
  {{- toYaml .namespaces | nindent 2 }}
{{- with .exceptions }}
labelSelector:
  matchExpressions:
    {{- include "podsecuritypolicies.renderExceptions" . | trim | nindent 4 }}
{{- end }}
{{- end }}

{{/* Render match inclusion */}}
{{- define "podsecuritypolicies.renderMatchInclusion" -}}
scope: Namespaced
kinds:
  - apiGroups: [""]
    kinds: ["Pod"]
namespaces:
  - {{ .namespace }}
labelSelector:
  matchLabels:
    {{- toYaml .labels | nindent 4 }}
{{- end }}
