{{/* provider templates for rclone */}}

{{- define "provider" -}}
{{- if get .type dict . | not }}
{{- printf "rclone-provider: %s enabled but not configured" .type | fail }}
{{- end }}

{{- if eq .type "azure" }}
{{- include "azure-provider" .azure }}
{{- else if eq .type "s3" }}
{{- include "s3-provider" .s3 }}
{{- else if eq .type "swift" }}
{{- include "swift-provider" .swift }}
{{- else }}
{{- printf "rclone-provider: unsupported type: %s" . | fail }}
{{- end }}
{{- end }}

{{- define "azure-provider" -}}
type: azureblob
account: {{ .storageAccountName }}
key: {{ .storageAccountKey }}
{{- end }}

{{- define "s3-provider" -}}
type: s3
provider: Other
endpoint: {{ .regionEndpoint }}
region: {{ .region }}
accessKeyId: {{ .accessKey }}
secretAccessKey: {{ .secretKey }}
v2Auth: {{ get "v2Auth" false . }}
forcePathStyle: {{ .forcePathStyle }}
{{- end }}

{{- define "swift-provider" -}}
type: swift
authVersion: {{ get "authVersion" 0 . }}
auth: {{ .authUrl }}
region: {{ .region }}

{{- if get "applicationCredentialID" "" . }}
# application credential auth with id
applicationCredentialId: {{ .applicationCredentialID }}

{{- if get "applicationCredentialSecret" "" . }}
applicationCredentialSecret: {{ .applicationCredentialSecret }}
{{- else }}
{{- fail "rclone-provider: swift authentication with application credential id requires application credential secret" }}
{{- end }}

{{- else if get "applicationCredentialName" "" . }}
# application credential auth with name
applicationCredentialName: {{ .applicationCredentialName }}
{{- if get "applicationCredentialSecret" "" . }}
applicationCredentialSecret: {{ .applicationCredentialSecret }}
{{- else }}
{{- fail "rclone-provider: swift authentication with application credential name requires application credential secret" }}
{{- end }}

{{- if get "userId" "" . }}
userId: {{ .userId }}
{{- else if get "username" "" . }}
user: {{ .username }}

{{- if get "userDomainName" "" . }}
domain: {{ .userDomainName }}
{{- else }}
{{- fail "rclone-provider: swift authentication with application credential name and user name requires user domain name" }}
{{- end }}

{{- else }}
{{- fail "rclone-provider: swift authentication with application credential name requires user reference" }}
{{- end }}

{{- else }}

{{- if get "userId" "" . }}
# user and password auth with id
userId: {{ .userId }}

{{- else if get "username" "" . }}
# user and password auth with name
user: {{ .username }}

{{- if get "userDomainName" "" . }}
domain: {{ .userDomainName }}
{{- else }}
{{- fail "rclone-provider: swift authentication with user name requires user domain name" }}
{{- end }}

{{- else }}
{{- fail "rclone-provider: swift authentication requires either application credentials or user and password" }}
{{- end }}

{{- if get "projectId" "" . }}
tenantId: {{ .projectId }}
{{- else if get "projectName" "" . }}
tenant: {{ .projectName }}

{{- if get "projectDomainName" "" . }}
tenantDomain: {{ .projectDomainName }}
{{- else }}
{{- fail "rclone-provider: swift authentication with user and password and project name requires project domain name" }}
{{- end }}

{{- else }}
{{- fail "rclone-provider: swift authentication with user and password requires project reference" }}
{{- end }}

{{- if get "password" }}
key: {{ .password }}
{{- else }}
{{- fail "rclone-provider: swift authentication with user requires password" }}
{{- end }}

{{- end }}
{{- end }}

{{- define "crypt-provider" -}}
{{- if get "enabled" false . -}}
enabled: true
{{- if get "fileNames" "" . }}
fileNamesEnabled: true
{{- if get "directoryNames" "" . }}
directoryNamesEnabled: true
{{- end }}
{{- end }}
{{- if get "passwordObscured" "" . | not }}
{{- fail "rclone-provider: crypt requires password obscured to be set" }}
{{- end }}
{{- if get "saltObscured" "" . | not }}
{{- fail "rclone-provider: crypt requires salt obscured to be set" }}
{{- end }}
password: {{ .passwordObscured }}
salt: {{ .saltObscured }}
{{- else -}}
enabled: false
{{- end }}
{{- end }}
