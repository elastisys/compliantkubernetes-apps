#!/usr/bin/env bash

: "${CK8S_CLUSTER:?Missing CK8S_CLUSTER}"

ROOT="$(readlink --canonicalize "$(dirname "${0}")/../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

results_mult_uniq=""

exempt_namepsaces=("rook-ceph")

function set_violating_resources() {
  results_mult_uniq=""
  results=()

  # Get violations for PSPs
  violations=$(kubectl_do "${CK8S_CLUSTER}" get constraints -o yaml | yq '[.items[] | select(.kind == "K8sPSP*") | .status.violations[]]')

  # Build array of maps with relevant information
  resources=$(echo "$violations" | yq '.[] |[{"name": .name, "namespace": .namespace}]' | yq 'unique_by(.name,.namespace)')

  # Create bash array to be able to loop over each entry
  readarray resource_arr < <(echo "$resources" | yq e -o=j -I=0 '.[]')

  for resource in "${resource_arr[@]}"; do
    namespace=$(echo "$resource" | yq e '.namespace')
    pod_name=$(echo "$resource" | yq e '.name')

    owner_reference=$(kubectl_do "${CK8S_CLUSTER}" -n "$namespace" get pod "$pod_name" --ignore-not-found=true -oyaml | yq '.metadata.ownerReferences.[0]')

    # Skip standalone Pods and stale references
    if [ "$owner_reference" = "null" ] || [ -z "$owner_reference" ]; then continue; fi

    owner_kind=$(echo "$owner_reference" | yq .kind)
    owner_name=$(echo "$owner_reference" | yq .name)

    # Skip jobs
    if [ "$owner_kind" == "Job" ]; then continue; fi

    # Get owner of ReplicaSets
    if [ "$owner_kind" == "ReplicaSet" ]; then
      owner_reference=$(kubectl_do "${CK8S_CLUSTER}" -n "$namespace" get rs "$owner_name" --ignore-not-found=true -oyaml | yq '.metadata.ownerReferences.[0]')

      # Skip standalone ReplicaSets and stale references
      if [ "$owner_reference" = "null" ] || [ -z "$owner_reference" ]; then continue; fi

      owner_kind=$(echo "$owner_reference" | yq .kind)
      owner_name=$(echo "$owner_reference" | yq .name)
    fi

    results+=('{name: '"$owner_name"', namespace: '"$namespace"', kind: '"$owner_kind"'}')
  done

  # Convert array to multiline string and keep only unique lines
  results_mult_uniq=$(printf "%s\n" "${results[@]}" | sort -u)
}

function is_customer_namespace() {
  namespace="$1"
  operator_ns_regex="^($(kubectl_do "${CK8S_CLUSTER}" get ns -l owner=operator '-ojsonpath={.items[*].metadata.name}' | sed 's/ /|/g'))$"

  if [[ "$namespace" =~ $operator_ns_regex ]]; then return 1; fi
}

function restart_violating_resources() {
  IFS=$'\n'
  # shellcheck disable=SC2128
  for entry in $results_mult_uniq; do
    kind=$(echo "$entry" | yq .kind)
    name=$(echo "$entry" | yq .name)
    namespace=$(echo "$entry" | yq .namespace)

    # shellcheck disable=SC2076
    if [[ "${exempt_namepsaces[*]}" =~ "${namespace}" ]] || is_customer_namespace "$namespace"; then
      log_warn "$kind/$name in $namespace for cluster ${CK8S_CLUSTER} requires manual restart"
    else
      if [[ -n "$(kubectl_do "${CK8S_CLUSTER}" get "$kind" "$name" -n "$namespace" --ignore-not-found=true -oname)" ]]; then
        log_info "Will trigger a rollout restart of $kind/$name in $namespace for cluster ${CK8S_CLUSTER}"
        kubectl_do "${CK8S_CLUSTER}" rollout restart "$kind" "$name" -n "$namespace"
      fi
    fi

  done
}

set_violating_resources
restart_violating_resources
