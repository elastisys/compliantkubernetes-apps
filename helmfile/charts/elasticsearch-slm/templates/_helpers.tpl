{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "elasticsearch-slm.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "elasticsearch-slm.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "elasticsearch-slm.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "elasticsearch-slm.labels" -}}
helm.sh/chart: {{ include "elasticsearch-slm.chart" . }}
{{ include "elasticsearch-slm.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "elasticsearch-slm.selectorLabels" -}}
app.kubernetes.io/name: {{ include "elasticsearch-slm.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

#{{/*
#Create the name of the service account to use
#*/}}
#{{- define "elasticsearch-slm.serviceAccountName" -}}
#{{- if .Values.serviceAccount.create -}}
#    {{ default (include "elasticsearch-slm.fullname" .) .Values.serviceAccount.name }}
#{{- else -}}
#    {{ default "default" .Values.serviceAccount.name }}
#{{- end -}}
#{{- end -}}
