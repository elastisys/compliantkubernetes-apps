{{/*
Parses a container image URI into its components:

- the 'registry' key will contain any material before the first slash
- the 'repository' will contain everything before the tag (this is in tune with the ingress-nginx chart semantics
  of an image 'repository', i.e. if specified it replaces the entirety of the URI up to the tag)
- the 'tag' (optional output) contains the tag, if specified
- the 'digest' (optional output) contains the image digest, if present
*/}}
{{- define "container_uri.parse" }}
  {{- $registry := (include "container_uri.registry" (dict "Image" .Image "Global" .Global.registry)) | trim }}
  {{- $repository := (include "container_uri.repository" (dict "Image" .Image "Global" .Global.repository)) | trim }}
  {{- $image := (include "container_uri.image" (dict "Image" .Image)) | trim }}
  {{- $tag := (include "container_uri.tag" (dict "Image" .Image) | trim )}}
  {{- $digest := (include "container_uri.digest" (dict "Image" .Image) | trim )}}
  {
    "registry": {{ quote ($registry) }},
    "repository": {{ quote ($repository) }},
    "image": {{ quote ($image) }},
    "tag": {{ quote ($tag) }},
    "digest": {{ quote ($digest) }},
    "_orig": {{ quote .Image }}
  }
{{- end }}


{{/*
An image has a "registry" if there are at least two "/"-separated fragments
and the first of them contains a "."
*/}}
{{- define "container_uri.registry" }}
  {{- $colonParts := regexSplit ":" .Image -1 }}
  {{- $slashParts := regexSplit "/" (first $colonParts) -1 }}
  {{- if and (ge (len $slashParts) 2) (contains "." (first $slashParts)) -}}
    {{ first $slashParts }}
  {{- else }}
    {{- if and .Global.enabled .Global.uri -}}
      {{ .Global.uri }}
    {{- end }}
  {{- end }}
{{- end }}

{{/*
An image has a "repository" if there are at least two "/"-separated fragments
after (potentially) removing the first "."-containing fragment.
*/}}
{{- define "container_uri.repository" }}
  {{- $colonParts := regexSplit ":" .Image -1 }}
  {{- $slashParts := regexSplit "/" (first $colonParts) -1 }}
  {{- $keepParts := ternary (slice $slashParts 1) ($slashParts) (contains "." (first $slashParts)) }}
  {{- if ge (len $keepParts) 2 -}}
    {{ join "/" (slice $keepParts 0 (sub (len $keepParts) 1)) }}
  {{- else }}
    {{- if and .Global.enabled .Global.uri -}}
      {{ .Global.uri }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "container_uri.image" }}
  {{- $colonParts := regexSplit ":" .Image -1 }}
  {{- $slashParts := regexSplit "/" (first $colonParts) -1 -}}
  {{ last $slashParts }}
{{- end }}

{{- define "container_uri.tag" }}
  {{- $atParts := regexSplit "@" .Image -1 }}
  {{- $colonParts := regexSplit ":" (first $atParts) -1 }}
  {{- if eq (len $colonParts) 2 -}}{{ (last $colonParts) }}{{- end}}
{{- end}}

{{- define "container_uri.digest" }}
  {{- $atParts := regexSplit "@" .Image -1 }}
  {{- if eq (len $atParts) 2 -}}{{ (last $atParts) }}{{- end}}
{{- end}}
