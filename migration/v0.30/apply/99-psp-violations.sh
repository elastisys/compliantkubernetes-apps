#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

results_mult_uniq=""

exempt_namepsaces=("rook-ceph")

function set_violating_resources() {
  results_mult_uniq=""
  results=()
  cluster="$1"

  # Get violations for PSPs
  violations=$(kubectl_do "$cluster" get constraints -o yaml | yq4 '[.items[] | select(.kind == "K8sPSP*") | .status.violations[]]')

  # Build array of maps with relevant information
  resources=$(echo "$violations" | yq4 '.[] |[{"name": .name, "namespace": .namespace}]' | yq4 'unique_by(.name,.namespace)')

  # Create bash array to be able to loop over each entry
  readarray resource_arr < <(echo "$resources" | yq4 e -o=j -I=0 '.[]')

  for resource in "${resource_arr[@]}"; do
    namespace=$(echo "$resource" | yq4 e '.namespace')
    pod_name=$(echo "$resource" | yq4 e '.name')

    owner_reference=$(kubectl_do "$cluster" -n "$namespace" get pod "$pod_name" --ignore-not-found=true -oyaml | yq4 '.metadata.ownerReferences.[0]')

    # Skip standalone Pods and stale references
    if [ "$owner_reference" = "null" ] || [ -z "$owner_reference" ]; then continue; fi

    owner_kind=$(echo "$owner_reference" | yq4 .kind)
    owner_name=$(echo "$owner_reference" | yq4 .name)

    # Skip jobs
    if [ "$owner_kind" == "Job" ]; then continue; fi

    # Get owner of ReplicaSets
    if [ "$owner_kind" == "ReplicaSet" ]; then
      owner_reference=$(kubectl_do "$cluster" -n "$namespace" get rs "$owner_name" -oyaml | yq4 '.metadata.ownerReferences.[0]')

      # Skip standalone ReplicaSets
      if [ "$owner_reference" = "null" ]; then continue; fi

      owner_kind=$(echo "$owner_reference" | yq4 .kind)
      owner_name=$(echo "$owner_reference" | yq4 .name)
    fi

    results+=('{name: '"$owner_name"', namespace: '"$namespace"', kind: '"$owner_kind"'}')
  done

  # Convert array to multiline string and keep only unique lines
  results_mult_uniq=$(printf "%s\n" "${results[@]}" | sort -u)
}

function is_customer_namespace() {
  namespace="$1"
  cluster="$2"
  operator_ns_regex="^($(kubectl_do "$cluster" get ns -l owner=operator '-ojsonpath={.items[*].metadata.name}' | sed 's/ /|/g'))$"

  if [[ "$namespace" =~ $operator_ns_regex  ]]; then return 1; fi
}

function restart_violating_resources() {
  IFS=$'\n'
  cluster="$1"
  # shellcheck disable=SC2128
  for entry in $results_mult_uniq; do
    kind=$(echo "$entry" | yq4 .kind)
    name=$(echo "$entry" | yq4 .name)
    namespace=$(echo "$entry" | yq4 .namespace)

    # shellcheck disable=SC2076
    if [[ "${exempt_namepsaces[*]}" =~ "${namespace}" ]] || is_customer_namespace "$namespace" "$cluster"; then
      log_warn "$kind/$name in $namespace for cluster $cluster requires manual restart"
    else
      log_info "Will trigger a rollout restart of $kind/$name in $namespace for cluster $cluster"
      kubectl_do "$cluster" rollout restart "$kind" "$name" -n "$namespace"
    fi

  done
}

run() {
  case "${1:-}" in
  execute)
    for cluster in sc wc; do
      set_violating_resources "$cluster"
      restart_violating_resources "$cluster"
    done
    ;;

  rollback)
    log_warn "rollback not applicable"
    ;;

  *)
    log_fatal "usage: \"${0}\" <execute|rollback>"
    ;;
  esac
}

run "${@}"
