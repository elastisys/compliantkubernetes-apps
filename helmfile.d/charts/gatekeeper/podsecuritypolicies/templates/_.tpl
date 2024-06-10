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
namespaceSelector:
  matchExpressions:
    {{- with .namespaceSelectorLabels }}
    {{- toYaml . | nindent 4 }}
    {{- else }}
    - key: kubernetes.io/metadata.name
      operator: In
      values: {{- toYaml .namespaces | nindent 8 }}
    {{- end }}
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
  {{- if .labels }}
  matchLabels:
    {{- toYaml .labels | nindent 4 }}
  {{- end }}
  {{- if .expressions }}
  matchExpressions:
    {{- toYaml .expressions | nindent 4 }}
  {{- end }}
{{- end }}
