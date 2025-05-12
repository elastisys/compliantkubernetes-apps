<!--
Parses a container image URI into its components:

- 'registry' will contain the fragment before the first "/", IF it contains a "."
- 'repository' will contain all but the last "/"-separated fragments, with the first one
  removed if it contains a "." (because it must be the registry)
- 'image' will contain the last '/'-separated fragment
- 'tag' (optional output) will contain the tag, if specified
- 'digest' (optional output) will contain the image digest, if present
- '_orig' will contain the original ".Image" input to the function

The function expects two arguments in a dictionary:
- 'Image' a container URI string
- 'Global' the object nested under the `.images.global` key from the configuration
-->
{{- define "container_uri.parse" }}
  {{ mustToJson (dict
    "registry" (include "container_uri.registry" . | trim)
    "repository" (include "container_uri.repository" . | trim)
    "image" (include "container_uri.image" . | trim)
    "tag" (include "container_uri.tag" . | trim)
    "digest" (include "container_uri.digest" . | trim)
    "uri" .Image
  )}}
{{- end }}

<!--
A container_uri has a "registry" if there are at least two "/"-separated fragments
and the first one contains a "."
-->
{{- define "container_uri.registry" }}
  {{- $colonParts := regexSplit ":" .Image -1 }}
  {{- $slashParts := regexSplit "/" (first $colonParts) -1 }}
  {{- if and (ge (len $slashParts) 2) (contains "." (first $slashParts)) -}}
    {{ first $slashParts }}
  {{- else }}
    {{- if dig "registry" "enabled" false .Global -}}
      {{ dig "registry" "uri" "" .Global }}
    {{- end }}
  {{- end }}
{{- end }}

<!--
A container_uri has a "repository" if there are at least two "/"-separated fragments
after (potentially) removing the first fragment as the "registry"
-->
{{- define "container_uri.repository" }}
  {{- $colonParts := regexSplit ":" .Image -1 }}
  {{- $slashParts := regexSplit "/" (first $colonParts) -1 }}
  {{- $keepParts := ternary (slice $slashParts 1) ($slashParts) (contains "." (first $slashParts)) }}
  {{- if ge (len $keepParts) 2 -}}
    {{ join "/" (slice $keepParts 0 (sub (len $keepParts) 1)) }}
  {{- else }}
    {{- if dig "repository" "enabled" false .Global -}}
      {{ dig "repository" "uri" "" .Global }}
    {{- end }}
  {{- end }}
{{- end }}

<!--
A container_uri has an "image" if it doesn't begin with ":" or "@",
and it's the fragment after the last "/" but before the ":" tag separator.
-->
{{- define "container_uri.image" }}
  {{- if and (not (hasPrefix "@" .Image)) (not (hasPrefix ":" .Image)) }}
    {{- $colonParts := regexSplit ":" .Image -1 }}
    {{- $slashParts := regexSplit "/" (first $colonParts) -1 -}}
    {{ last $slashParts }}
  {{- end }}
{{- end }}

<!--
A container_uri has a tag if the ":" separator is present, and it's the fragment
after the separator. We also chop after the "@" digest separator if present.
-->
{{- define "container_uri.tag" }}
  {{- $atParts := regexSplit "@" .Image -1 }}
  {{- $colonParts := regexSplit ":" (first $atParts) -1 }}
  {{- if eq (len $colonParts) 2 -}}{{ (last $colonParts) }}{{- end}}
{{- end}}

<!--
A container_uri has a digest if the "@" separator is present, and it's the fragment
after the separator.
-->
{{- define "container_uri.digest" }}
  {{- $atParts := regexSplit "@" .Image -1 }}
  {{- if eq (len $atParts) 2 -}}{{ (last $atParts) }}{{- end}}
{{- end}}
