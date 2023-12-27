{{/*
Expand the name of the chart.
*/}}
{{- define "tektonDashboard.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "tektonDashboard.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}


{{- define "tektonDashboard.labels" -}}
app.kubernetes.io/component: dashboard
app.kubernetes.io/instance: {{ template "tektonDashboard.fullname". }}
app.kubernetes.io/part-of: tekton-dashboard
helm-release: {{ .Release.Name | quote }}
helm.sh/chart: "{{ .Chart.Name }}-{{ .Chart.Version}}"
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}

{{- define "tektonDashboard.labelselector" -}}
app.kubernetes.io/instance: {{ template "tektonDashboard.fullname". }}
app.kubernetes.io/component: dashboard
app.kubernetes.io/name: dashboard
app.kubernetes.io/part-of: tekton-dashboard
{{- end }}

{{- define "dashboard.image" -}}
{{- printf "%s:%s@%s" .repository .tag .digest -}}
{{- end -}}
