#!/usr/bin/env bash

# returns the releases filtered on { condition: true, installed: true } for the given cluster <sc|wc>
# additionally sets { selector: "namespace=<release-namespace>,name=<release-name>" } for subsequent filtering
# additionally sets { needs: [ "namespace=<needs-namespace>,name=<needs-name>" ] } for subsequent filtering
# caches the results
helmfile_build_releases() {
  local releases expression
  releases="${CK8S_CONFIG_PATH}/pre-build/${1}.yaml"


  if ! [[ -f "${releases}" ]]; then
    mkdir -p "$(dirname "${releases}")"

    # with the merged config as $values, select releases with condition and installed not false,
    # set selector with format "namespace=%,name=%", set needs with format "namespace=%,name=%", collect to array
    # shellcheck disable=SC2016
    expression='.renderedvalues as $values | [
      .releases[] |
      select(
        eval("$values." + .condition) != false and .installed != false
      ) |
      .selector = "namespace=" + .namespace + ",name=" + .name |
      with(.needs[];
        . = "namespace=" + sub("/", ",name=")
      )
    ]'

    local target
    target="$(mktemp)"

    case "${1:-}" in
    sc)
      helmfile -e service_cluster -f "${ROOT}/helmfile.d" -q build | yq -oj -I0 "${expression}" > "${target}"
      ;;
    wc)
      helmfile -e workload_cluster -f "${ROOT}/helmfile.d" -q build | yq -oj -I0 "${expression}" > "${target}"
      ;;
    *)
      echo "error: usage: helmfile_build_releases <sc|wc>"
      exit 1
      ;;
    esac

    mv "${target}" "${releases}"
  fi

  cat "${releases}"
}

# returns the resolved transitive needs for the given cluster <sc|wc> and selector "namespace=<namespace>,name=<name>"
helmfile_build_needs() {
  local releases incoming outgoing

  releases="$(helmfile_build_releases "${1}")"

  incoming=""
  outgoing="${2}"

  # until the data does not change between iterations
  while [[ "${incoming}" != "${outgoing}" ]]; do
    # save outgoing selectors for next iteration
    incoming="${outgoing}"
    # from releases. select anything matching the incoming selectors,
    # generate a list from releases with its selector and needs,
    # take unique selectors and join them with a space
    outgoing="$(yq "[
      .[] | select(
        .selector | match(\"${incoming// /|}\")
      ) | .needs + [.selector] | .[]
    ] | sort | unique | join(\" \") " <<< "${releases}")"
  done

  echo "${outgoing// /$'\n'}"
}

# creates a cache with templated releases
helmfile_template_releases() {
  local target_template
  target_template="${CK8S_CONFIG_PATH}/pre-template/${1}/namespace={{ .Release.Namespace }},name={{ .Release.Name }}"

  case "${1:-}" in
  sc)
    # template matching release and add namespace of release if missing
    helmfile -e service_cluster -f "${ROOT}/helmfile.d" -q template --include-crds --output-dir-template "${target_template}"
    ;;
  wc)
    # template matching release and add namespace of release if missing
    helmfile -e workload_cluster -f "${ROOT}/helmfile.d" -q template --include-crds --output-dir-template "${target_template}"
    ;;
  *)
    echo "error: usage: helmfile_template_release <sc|wc> <selector>"
    exit 1
    ;;
  esac
}

# returns the templated release for the given cluster <sc|wc> and selector "namespace=<namespace>,name=<name>" from cache
helmfile_template_release() {
  local release
  release="${CK8S_CONFIG_PATH}/pre-template/${1}/${2}"

  if [[ -d "${release}" ]]; then
    # get namespace from selector
    local namespace="${2}"
    namespace="${namespace##namespace=}"
    namespace="${namespace%%,name=*}"

    local -a files
    readarray -t files <<< "$(find "${release}" -type f -name '*.yaml')"

    for file in "${files[@]}"; do
      yq ".metadata.namespace = (.metadata.namespace // \"${namespace}\")" "${file}"
    done

  else
    echo "error: missing release ${1}/${2}" >&2
    exit 1
  fi
}

# returns the templated release and transitive needs for the given cluster <sc|wc> and selector "namespace=<namespace>,name=<name>"
# caches the results
helmfile_template_release_needs() {
  local -a selectors
  readarray -t selectors <<< "$(helmfile_build_needs "${1}" "${2}")"

  local selector
  for selector in "${selectors[@]}"; do
    helmfile_template_release "${1}" "${selector}"
  done
}

# renders templates in two passes for each release, with and without transitive needs
# arguments: <sc|wc> <yq-expression-for-used-resources> <yq-expression-for-created-resources>
# - the <yq-expression-for-used-resources> should create unique identifiers for resources that the release depends on based on the rendered templates **without** transitive needs
# - the <yq-expression-for-created-resources> should create unique identifiers for resources that the releases provides based on the rendered templates **with** transitive needs
releases_have_through_needs() {
  local cluster used_expression created_expression

  cluster="${1}"
  used_expression="${2}"
  created_expression="${3}"

  local -a selectors
  readarray -t selectors <<< "$(helmfile_build_releases "${cluster}" | yq -r -oj -I0 '.[] | "namespace=" + .namespace + ",name=" + .name')"

  local fail=false

  local selector
  for selector in "${selectors[@]}"; do
    local used_resources
    used_resources="$(helmfile_template_release "${cluster}" "${selector}" | yq -N "select(. != null) | [${used_expression}] | .[]" | sort -u)"

    local created_resources
    created_resources="$(helmfile_template_release_needs "${cluster}" "${selector}" | yq -N "select(. != null) | [${created_expression}] | .[]" | sort -u)"

    local uniques
    # print used resources once and created resources twice, then filter on totally unique identifiers
    uniques="$(tr ' ' '\n' <<< "${used_resources} ${created_resources} ${created_resources}" | sort | uniq -u | tr '\n' ' ')"

    # if we have a totally unique identifier then we have an issue
    if [[ -n "${uniques%% }" ]]; then
      echo "error: release {${selector}} requires [${uniques%% }] which seems to be missing from its needs!"
      fail=true
    fi
  done

  if [[ "${fail}" == "true" ]]; then
    exit 1
  fi
}

release_with_custom_resources_have_validation_on_install_disabled() {
  local -a selectors
  readarray -t selectors <<< "$(helmfile_build_releases "${1}" | yq -r -oj -I0 '.[] | select(.disableValidationOnInstall != true) | "namespace=" + .namespace + ",name=" + .name')"

  local fail=false

  local selector
  for selector in "${selectors[@]}"; do
    local custom_resources
    custom_resources="$(helmfile_template_release "${1}" "${selector}" | yq -r -oj -I0 'select(.apiVersion | test("^(.+\.k8s\.io/|apps/|batch/|policy/|)v1.*") | not) | .apiVersion + "/" + .kind' | sort -u)"

    if [[ -n "${custom_resources}" ]]; then
      echo "error: release {${selector//=/:}} creates custom resources [${custom_resources//$'\n'/,}] and must have { disableValidationOnInstall: true }!"
      fail=true
    fi
  done

  if [[ "${fail}" == "true" ]]; then
    exit 1
  fi
}
