{{- define "velero.plugin_image" }}
{{- $global := dict
  "registry" (ternary (dig "uri" "" .images.global.registry) "" .images.global.registry.enabled)
  "repository" (ternary (dig "uri" "" .images.global.repository) "" .images.global.repository.enabled)
}}
{{- $key := . | dig "key" "" }}
{{- if not $key }}{{ fail "\nERROR: Missing .key argument" }}{{ end }}
{{- with .images | dig "velero" $key "" }}
{{- with merge (include "container_uri.parse" . | fromJson) $global }}
{{- include "gen.container_uri" . | quote }}
{{- end }}
{{- else }}
{{- . | dig "default" "" | quote }}
{{- end }}
{{- end }}
