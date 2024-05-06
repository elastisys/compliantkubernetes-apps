#!/usr/bin/env bash

helmfile_template_kubeconform() {
  mkdir -p /tmp/compliantkubernetes-apps-tests-unit-kubeconform

  helmfile -e "${1}" -f "${ROOT}/helmfile.d/" -q template | \
    kubeconform -cache /tmp/compliantkubernetes-apps-tests-unit-kubeconform -ignore-missing-schemas -schema-location default -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' -strict -summary -
}
