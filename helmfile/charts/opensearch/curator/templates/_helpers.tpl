{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "opensearch-curator.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "opensearch-curator.fullname" -}}
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
{{- define "opensearch-curator.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "opensearch-curator.labels" -}}
helm.sh/chart: {{ include "opensearch-curator.chart" . }}
{{ include "opensearch-curator.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "opensearch-curator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "opensearch-curator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

#{{/*
#Create the name of the service account to use
#*/}}
#{{- define "opensearch-curator.serviceAccountName" -}}
#{{- if .Values.serviceAccount.create -}}
#    {{ default (include "opensearch-curator.fullname" .) .Values.serviceAccount.name }}
#{{- else -}}
#    {{ default "default" .Values.serviceAccount.name }}
#{{- end -}}
#{{- end -}}
