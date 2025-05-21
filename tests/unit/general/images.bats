#!/usr/bin/env bats

# bats file_tags=releases,general

setup_file() {
  # for dynamically registering tests using `bats_test_function`
  bats_require_minimum_version 1.11.1

  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "gpg.bash"
  load_common "yq.bash"

  gpg.setup
  env.setup

  env.init openstack capi dev

  yq.set sc .externalDns.enabled 'true'
  yq.set sc .fluentd.enabled 'true'
  yq.set sc .gpu.enabled 'true'
  yq.set sc .harbor.backup.enabled 'true'
  yq.set wc .hnc.enabled 'true'
  yq.set sc .kured.enabled 'true'
  yq.set sc .kyverno.enabled 'true'
  yq.set sc .opensearch.snapshot.enabled 'true'
}

setup() {
  load "../../bats.lib.bash"
  load_assert
  load_common "yq.bash"
  load_common "env.bash"
  env.private

  export _templates_output="${CK8S_CONFIG_PATH}/tmp/images-templates"

  read -r -a _image_properties < <(_get_test_prop image_property)
  read -r -a _helmfile_selectors < <(_get_test_prop helmfile_selector)
  read -r -a _container_names < <(_get_test_prop container_name)
  read -r -a _template_files < <(_get_test_prop template_file)
}

teardown_file() {
  env.teardown
  gpg.teardown
}

declare -a _test_functions
_test_functions=(
  should_be_set
  should_use_our_image
  should_use_our_image_and_tag
  should_use_our_image_tag_and_digest
  should_use_our_repository_image_tag_and_digest
  should_use_our_registry_repository_image_tag_and_digest
  should_use_their_own_registry_even_when_global_is_enabled
  should_use_the_global_registry_when_it_doesnt_specify_one
  should_use_their_own_repository_even_when_global_is_enabled
  should_use_the_global_repository_when_it_doesnt_specify_one
  should_use_the_global_repository_with_their_own_registry
  should_use_the_global_registry_with_their_own_repository
  should_allow_overwriting_the_tag_fragment_only
  should_allow_overwriting_the_tag_and_sha_fragments_only
  should_not_set_the_image_field_if_only_sha_is_specified
)

for _test_function in "${_test_functions[@]}"; do
  bats_test_function \
    --description "container images ${_test_function//_/ }" \
    -- "${_test_function}"
done

should_be_set() {
  _generate_templates

  for ((i = 0; i < ${#_container_names[@]}; i++)); do
    assert [ "$(_extract_image "${_container_names[i]}" "${_template_files[i]}")" != "" ]
  done
}

should_use_our_image() {
  _set_container_uris "a-custom-image"
  _generate_templates

  for ((i = 0; i < ${#_container_names[@]}; i++)); do
    run --separate-stderr _extract_image "${_container_names[i]}" "${_template_files[i]}"

    assert_output --regexp '^(docker\.io/)?(nvcr\.io/nvidia/)?(ghcr\.io/)?a-custom-image.*$'
  done
}

should_use_our_image_and_tag() {
  _set_container_uris "a-custom-image:v1.2.3"
  _generate_templates

  for ((i = 0; i < ${#_container_names[@]}; i++)); do
    run --separate-stderr _extract_image "${_container_names[i]}" "${_template_files[i]}"

    assert_output --regexp '^(docker\.io/)?(nvcr\.io/nvidia/)?(ghcr\.io/)?a-custom-image:v1\.2\.3$'
  done
}

should_use_our_image_tag_and_digest() {
  _set_container_uris "a-custom-image:v1.2.3@sha256:babafacecaca"
  _generate_templates

  for ((i = 0; i < ${#_container_names[@]}; i++)); do
    run --separate-stderr _extract_image "${_container_names[i]}" "${_template_files[i]}"

    assert_output --regexp '^(docker\.io/)?(nvcr\.io/nvidia/)?(ghcr\.io/)?a-custom-image:v1\.2\.3@sha256:babafacecaca$'
  done
}

should_use_our_repository_image_tag_and_digest() {
  _set_container_uris "a-custom-repo/a-custom-image:v1.2.3@sha256:babafacecaca"
  _generate_templates

  for ((i = 0; i < ${#_container_names[@]}; i++)); do
    run --separate-stderr _extract_image "${_container_names[i]}" "${_template_files[i]}"

    assert_output --regexp '^(docker\.io/)?(nvcr\.io/nvidia/)?(ghcr\.io/)?a-custom-repo/a-custom-image:v1\.2\.3@sha256:babafacecaca$'
  done
}

should_use_our_registry_repository_image_tag_and_digest() {
  _set_container_uris "a-custom-registry.com/a-custom-repo/a-custom-image:v1.2.3@sha256:babafacecaca"
  _generate_templates

  for ((i = 0; i < ${#_container_names[@]}; i++)); do
    run --separate-stderr _extract_image "${_container_names[i]}" "${_template_files[i]}"

    assert_output --regexp '^a-custom-registry\.com/a-custom-repo/a-custom-image:v1\.2\.3@sha256:babafacecaca$'
  done
}

should_use_their_own_registry_even_when_global_is_enabled() {
  _enable_global_registry "the-global-registry.com"
  _set_container_uris "a-custom-registry.com/a-custom-image:v1.2.3"
  _generate_templates

  for ((i = 0; i < ${#_container_names[@]}; i++)); do
    run --separate-stderr _extract_image "${_container_names[i]}" "${_template_files[i]}"

    assert_output --regexp '^a-custom-registry\.com/a-custom-image:v1\.2\.3'
  done
}

should_use_the_global_registry_when_it_doesnt_specify_one() {
  _enable_global_registry "the-global-registry.com"
  _set_container_uris "a-custom-image:v1.2.3"
  _generate_templates

  for ((i = 0; i < ${#_container_names[@]}; i++)); do
    run --separate-stderr _extract_image "${_container_names[i]}" "${_template_files[i]}"

    assert_output --regexp '^the-global-registry\.com/a-custom-image:v1\.2\.3'
  done
}

should_use_their_own_repository_even_when_global_is_enabled() {
  _enable_global_repository "the-global-repository"
  _set_container_uris "a-custom-repository/a-custom-image:v1.2.3"
  _generate_templates

  for ((i = 0; i < ${#_container_names[@]}; i++)); do
    run --separate-stderr _extract_image "${_container_names[i]}" "${_template_files[i]}"

    assert_output --regexp '^(docker\.io/)?(nvcr\.io/nvidia/)?(ghcr\.io/)?a-custom-repository/a-custom-image:v1\.2\.3'
  done
}

should_use_the_global_repository_when_it_doesnt_specify_one() {
  _enable_global_repository "the-global-repository"
  _set_container_uris "a-custom-image:v1.2.3"
  _generate_templates

  for ((i = 0; i < ${#_container_names[@]}; i++)); do
    run --separate-stderr _extract_image "${_container_names[i]}" "${_template_files[i]}"

    assert_output --regexp '^(docker\.io/)?(nvcr\.io/nvidia/)?(ghcr\.io/)?the-global-repository/a-custom-image:v1\.2\.3'
  done
}

should_use_the_global_repository_with_their_own_registry() {
  _enable_global_repository "the-global-repository"
  _set_container_uris "my-own-registry.com/a-custom-image:v1.2.3"
  _generate_templates

  for ((i = 0; i < ${#_container_names[@]}; i++)); do
    run --separate-stderr _extract_image "${_container_names[i]}" "${_template_files[i]}"

    assert_output --regexp '^my-own-registry\.com/the-global-repository/a-custom-image:v1\.2\.3'
  done
}

should_use_the_global_registry_with_their_own_repository() {
  _enable_global_registry "the-global-registry.com"
  _set_container_uris "my-own-repository/a-custom-image:v1.2.3"
  _generate_templates

  for ((i = 0; i < ${#_container_names[@]}; i++)); do
    run --separate-stderr _extract_image "${_container_names[i]}" "${_template_files[i]}"

    assert_output --regexp '^the-global-registry\.com/my-own-repository/a-custom-image:v1\.2\.3'
  done
}

should_allow_overwriting_the_tag_fragment_only() {
  _set_container_uris ":v1.2.3"
  _generate_templates

  for ((i = 0; i < ${#_container_names[@]}; i++)); do
    run --separate-stderr _extract_image "${_container_names[i]}" "${_template_files[i]}"

    assert_output --regexp '^[^:]*:v1\.2\.3'
  done
}

should_allow_overwriting_the_tag_and_sha_fragments_only() {
  _set_container_uris ":v1.2.3@sha256:babafacecaca"
  _generate_templates

  for ((i = 0; i < ${#_container_names[@]}; i++)); do
    run --separate-stderr _extract_image "${_container_names[i]}" "${_template_files[i]}"

    assert_output --regexp '^[^:]*:v1\.2\.3@sha256:babafacecaca'
  done
}

should_not_set_the_image_field_if_only_sha_is_specified() {
  _set_container_uris "@sha256:babafacecaca"
  _generate_templates

  for ((i = 0; i < ${#_container_names[@]}; i++)); do
    local num_appears
    num_appears="$(_extract_image "${_container_names[i]}" "${_template_files[i]}" | grep -o "babafacecaca" | wc -l)"

    assert [ "$num_appears" == "1" ]
  done
}

_set_container_uris() {
  for _image_property in "${_image_properties[@]}"; do
    yq.set sc ".images.${_image_property}" "\"${1}\""
    yq.set wc ".images.${_image_property}" "\"${1}\""
  done
}

_enable_global_registry() {
  yq.set sc .images.global.registry.enabled 'true'
  yq.set sc .images.global.registry.uri "\"${1}\""
  yq.set wc .images.global.registry.enabled 'true'
  yq.set wc .images.global.registry.uri "\"${1}\""
}

_enable_global_repository() {
  yq.set sc .images.global.repository.enabled 'true'
  yq.set sc .images.global.repository.uri "\"${1}\""
  yq.set wc .images.global.repository.enabled 'true'
  yq.set wc .images.global.repository.uri "\"${1}\""
}

_generate_templates() {
  local _selector_args=()
  for _helmfile_selector in "${_helmfile_selectors[@]}"; do
    _selector_args+=("--selector" "${_helmfile_selector}")
  done

  helmfile -e service_cluster "${_selector_args[@]}" -f "${ROOT}/helmfile.d" -q template --output-dir-template "${_templates_output}/sc" || true
  helmfile -e workload_cluster "${_selector_args[@]}" -f "${ROOT}/helmfile.d" -q template --output-dir-template "${_templates_output}/wc" || true
}

_get_test_prop() {
  local _prop
  _prop="${1}"
  jq -r "[.parameters[] | .${_prop}] | join(\" \")" "${BATS_TEST_DIRNAME}/resources/images-parametric-tests.json"
}

_extract_image() {
  local _container_name _template_file
  _container_name="${1}"
  _template_file="${2}"

  echo >&2 "container_name=${_container_name} template_file=${_template_file}"

  yq '(
      (.spec.template.spec.containers // [])
    + (.spec.template.spec.initContainers // [])
    + (.spec.jobTemplate.spec.template.spec.containers // [])
    ) | .[] | select(.name == "'"${_container_name}"'") | .image' <"${_templates_output}/${_template_file}"
}
