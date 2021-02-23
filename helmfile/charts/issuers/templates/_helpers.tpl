{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "provisioner.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "provisioner.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Validate values of Issuer Email:
- must provide a valid email to LetsEncrypt
*/}}
{{- define "issuers.validateValues.letsencrypt.prod.email" -}}
{{- if and .Values.letsencrypt.enabled (not (regexMatch "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$" .Values.letsencrypt.prod.email)) -}}
issuers: letsencrypt.prod.email
    You must provide a valid email address (me@example.com).
{{- end -}}
{{- end -}}

{{- define "issuers.validateValues.letsencrypt.staging.email" -}}
{{- if and .Values.letsencrypt.enabled (not (regexMatch "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$" .Values.letsencrypt.staging.email)) -}}
issuers: letsencrypt.staging.email
    You must provide a valid email address (me@example.com).
{{- end -}}
{{- end -}}

{{/*
Compile all warnings into a single message, and call fail.
*/}}
{{- define "issuers.validateValues" -}}
{{- $messages := list -}}
{{- $messages := append $messages (include "issuers.validateValues.letsencrypt.prod.email" .) -}}
{{- $messages := append $messages (include "issuers.validateValues.letsencrypt.staging.email" .) -}}
{{- $messages := without $messages "" -}}
{{- $message := join "\n" $messages -}}

{{- if $message -}}
{{-   printf "\nVALUES VALIDATION:\n%s" $message | fail -}}
{{- end -}}
{{- end -}}
