#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(readlink -f "${0}")")"
root="$(dirname "$(dirname "${here}")")"

if command -v kube-score &>/dev/null; then
  cmd="kube-score"
elif command -v docker &>/dev/null; then
  echo "warning: kube-score (https://github.com/zegl/kube-score) is not installed, using docker (docker.io/zegl/kube-score:latest)" >&2
  cmd="docker run -i --rm docker.io/zegl/kube-score:latest"
else
  echo "error: kube-score (https://github.com/zegl/kube-score) is not installed and docker is unavailable" >&2
  exit 1
fi

score() {
  local target
  target="${1}"

  shift

  local releases
  releases="$(helmfile --allow-no-matching-release -e "${target}_cluster" -f "${root}/helmfile.d/" list "${@/#/-l}" -q --output json)"
  releases="$(yq -Poj '[.[] | select(.enabled and .installed) | {"namespace": .namespace, "name": .name}] | sort_by(.namespace, .name)' <<<"${releases}")"

  local length
  length="$(yq -Poy 'length' <<<"${releases}")"

  for index in $(seq 0 $((length - 1))); do
    namespace="$(yq -Poy ".[${index}].namespace" <<<"${releases}")"
    name="$(yq -Poy ".[${index}].name" <<<"${releases}")"

    echo "templating ${target}/${namespace}/${name}" >&2
    helmfile -e "${target}_cluster" -f "${root}/helmfile.d/" template -q "-lnamespace=${namespace},name=${name}" | yq "with(select(.metadata.namespace == null); .metadata.namespace = \"${namespace}\")"
    echo "---"
  done | $cmd score - --output-format=json --ignore-test container-image-pull-policy,container-ephemeral-storage-request-and-limit --kubernetes-version v1.24 || true
}

human_filter() {
  yq -Poy '{
    "'"${1}"'": [
      .[] | {
        "kind": .type_meta.apiVersion + "/" + .type_meta.kind,
        "name": .object_meta.namespace + "/" + .object_meta.name,
        "skips": [
          .checks[] | select(.grade != 10 and .skipped == true) | {
            "name": .check.name,
            "status": [
              .comments[] | {"component": .path, "summary": .summary, "description": .description}
            ]
          }
        ],
        "fails": [
          .checks[] | select(.grade != 10 and .skipped == false) | {
            "name": .check.name,
            "status": [
              .comments[] | {"component": .path, "summary": .summary, "description": .description}
            ]
          }
        ]
      } | with(select(.skips[] | has("name") | not); del(.skips)) | with(select(.fails[] | has("name") | not); del(.fails)) | select(has("skips") or has("fails"))
    ] | sort_by(.name)
  }'
}

machine_filter() {
  yq -Pocsv '
    with(.[].[].fails[];
      . |= [
        {
          "type": "fail",
          "check": .name,
          "status": .status[]
        }
      ]
    ) | with(.[].[].fails;
      . |= flatten
    ) | with(.[].[].skips[];
      . |= [
        {
          "type": "skip",
          "check": .name,
          "status": .status[]
        }
      ]
    ) | with(.[].[].skips;
      . |= flatten
    ) | with(.[].[];
      .checks |= [] | .checks += .fails | .checks += .skips | del(.fails, .skips)
    ) | with(.[].[];
      . |= [
        {
          "kind": .kind,
          "name": .name,
          "checks": .checks[]
        }
      ]
    ) | with(.[];
      . |= flatten
    ) | [
      {
        "cluster": "service",
        "resources": .service[]
      },
      {
        "cluster": "workload",
        "resources": .workload[]
      }
    ] | with(.[];
      . |= [
        .cluster,
        .resources.kind,
        .resources.name,
        .resources.checks.type,
        .resources.checks.check,
        .resources.checks.status.component,
        .resources.checks.status.summary,
        .resources.checks.status.description
      ]
    ) | [
      [
        "cluster",
        "kind",
        "name",
        "type",
        "check",
        "component",
        "summary",
        "description"
      ]
    ] + .
  '
}

case "${1:-}" in
score)
  for target in service workload; do
    score "${target}" "${@:2}" | human_filter "${target}"
  done
  ;;
report)
  for target in service workload; do
    score "${target}" "${@:2}" | human_filter "${target}"
  done | machine_filter
  ;;

*)
  echo "missing or invalid command" >&2
  echo >&2
  echo "${0}: run kube-score against a config directory" >&2
  echo >&2
  echo "usage:" >&2
  echo "- ${0} score [selectors...]  - scores and prints results in a human readable yaml format" >&2
  echo "- ${0} report [selectors...] - scores and prints results in a machine readable csv format" >&2
  echo >&2
  echo "selectors are expected to be <key>=<value> pairs to match releases in helmfile" >&2
  ;;
esac
