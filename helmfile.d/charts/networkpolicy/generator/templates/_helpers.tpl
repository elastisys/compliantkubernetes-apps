{{/* chart name */}}
{{- define "networkpolicy-generator.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* full name */}}
{{- define "networkpolicy-generator.fullname" -}}
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

{{/* chart and version */}}
{{- define "networkpolicy-generator.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* common labels */}}
{{- define "networkpolicy-generator.labels" -}}
helm.sh/chart: {{ include "networkpolicy-generator.chart" . }}
{{ include "networkpolicy-generator.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* selector labels */}}
{{- define "networkpolicy-generator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "networkpolicy-generator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* rule comment generator */}}
{{- define "networkpolicy-generator.generateRuleComment" -}}
{{- if and (hasKey . "name") (hasKey . "rule") }}
{{- printf "# rule: %s - base: %s\n    " .name .rule }}
{{- else if hasKey . "name" }}
{{- printf "# rule: %s\n    " .name }}
{{- else if hasKey . "rule" }}
{{- printf "# base: %s\n    " .rule }}
{{- end }}
{{- end }}

{{/* rule peer generator */}}
{{- define "networkpolicy-generator.generateRulePeer" -}}

{{- if hasKey . "raw" -}}
{{ .raw | toYaml | trim }}
{{- else if hasKey . "cidr" -}}
ipBlock:
  cidr: {{ .cidr }}
{{- else -}}
{{- if hasKey . "namespaceSelectorLabels" }}
namespaceSelector:
  {{- with .namespaceSelectorLabels }}
  matchLabels: {{ toYaml . | nindent 4 }}
  {{- else }} {}{{- end }}
{{- end }}
{{- if hasKey . "podSelectorLabels" }}
podSelector:
  {{- with .podSelectorLabels }}
  matchLabels: {{ toYaml . | nindent 4 }}
  {{- else }} {}{{- end }}
{{- end }}
{{- end }}

{{- end }}

{{/* rule peers generator */}}
{{- define "networkpolicy-generator.generateRulePeers" -}}

{{- range . }}
- {{ include "networkpolicy-generator.generateRulePeer" . | nindent 2 | trim }}
{{- end }}

{{- end }}

{{/* rule port generator */}}
{{- define "networkpolicy-generator.generateRulePort" -}}

{{- range $proto, $port := . }}
protocol: {{ $proto | upper }}
port: {{ $port }}
{{- end }}

{{- end }}

{{/* rule ports generator */}}
{{- define "networkpolicy-generator.generateRulePorts" -}}

{{- range . }}
- {{ include "networkpolicy-generator.generateRulePort" . | nindent 2 | trim }}
{{- end }}

{{- end }}

{{/* egress rule generator */}}
{{- define "networkpolicy-generator.generateEgressRule" -}}

{{- with .peers }}
to:
  {{ include "networkpolicy-generator.generateRulePeers" . | nindent 2 | trim }}
{{- end }}
{{- with .ports }}
ports:
  {{ include "networkpolicy-generator.generateRulePorts" . | nindent 2 | trim }}
{{- end -}}

{{- end }}

{{/* ingress rule generator */}}
{{- define "networkpolicy-generator.generateIngressRule" -}}

{{- with .peers }}
from:
  {{ include "networkpolicy-generator.generateRulePeers" . | nindent 2 | trim }}
{{- end }}
{{- with .ports }}
ports:
  {{ include "networkpolicy-generator.generateRulePorts" . | nindent 2 | trim }}
{{- end -}}

{{- end }}
