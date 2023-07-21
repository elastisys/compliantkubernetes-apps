{{/*
Do not update alertmanager secret if exists
*/}}
{{- define "gen.secret" -}}
{{- $secret := lookup "v1" "Secret" .Release.Namespace "alertmanager-alertmanager" -}}
{{- if $secret -}}
{{/*
  Reusing existing secret data
*/}}
alertmanager.yaml: {{ index $secret.data "alertmanager.yaml" }}
{{- else -}}
{{/*
  Generate new data
*/}}
alertmanager.yaml: {{ .Files.Get "files/alertmanager-config.yaml" | b64enc }}
{{- end -}}
{{- end -}}
