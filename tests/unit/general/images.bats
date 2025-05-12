#!/usr/bin/env bats

# bats file_tags=releases,general

setup_file() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "gpg.bash"
  load_common "yq.bash"

  gpg.setup
  env.setup

  env.init openstack capi dev
}

setup() {
  load "../../bats.lib.bash"
  load_assert
  load_common "yq.bash"
  load_common "env.bash"
  env.private

  export _templates_output="${CK8S_CONFIG_PATH}/tmp/images-templates"
  export _helmfile_selector="-lapp=ingress-nginx"
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
  should_use_its_own_registry_even_when_global_is_enabled
  should_use_the_global_registry_when_it_doesnt_specify_one
  should_use_its_own_repository_even_when_global_is_enabled
  should_use_the_global_repository_when_it_doesnt_specify_one
  should_use_the_global_repository_with_its_own_registry
  should_use_the_global_registry_with_its_own_repository
  should_allow_overwriting_the_tag_fragment_only
  should_allow_overwriting_the_tag_and_sha_fragments_only
  should_not_set_the_image_field_if_only_sha_is_specified
)

declare -a _parameters
for _test_case in $(jq -r '.parameters[] | @base64' "${BATS_TEST_DIRNAME}/resources/images-parametric-tests.json"); do
  _jq() {
    echo "${_test_case}" | base64 --decode | jq -r "${1}"
  }

  _image_property="$(_jq '.image_property')"
  _parameters=(
    "${_image_property}"
    "$(_jq '.container_name')"
    "$(_jq '.template_file')"
  )

  for _test_function in "${_test_functions[@]}"; do
    bats_test_function \
      --description "the ${_image_property} container image ${_test_function//_/ }" \
      -- "${_test_function}" "${_parameters[@]}"
  done
done

should_be_set() {
  _export_params "${@}"
  _generate_templates

  assert [ "$(_extract_image)" != "" ]
}

should_use_our_image() {
  _export_params "${@}"
  _set_container_uri "a-custom-image"
  _generate_templates

  run _extract_image

  assert_output --regexp '^a-custom-image.*$'
}

should_use_our_image_and_tag() {
  _export_params "${@}"
  _set_container_uri "a-custom-image:v1.2.3"
  _generate_templates

  run _extract_image

  assert_output --regexp '^a-custom-image:v1\.2\.3$'
}

should_use_our_image_tag_and_digest() {
  _export_params "${@}"
  _set_container_uri "a-custom-image:v1.2.3@sha256:babafacecaca"
  _generate_templates

  run _extract_image

  assert_output --regexp '^a-custom-image:v1\.2\.3@sha256:babafacecaca$'
}

should_use_our_repository_image_tag_and_digest() {
  _export_params "${@}"
  _set_container_uri "a-custom-repo/a-custom-image:v1.2.3@sha256:babafacecaca"
  _generate_templates

  run _extract_image

  assert_output --regexp '^a-custom-repo/a-custom-image:v1\.2\.3@sha256:babafacecaca$'
}

should_use_our_registry_repository_image_tag_and_digest() {
  _export_params "${@}"
  _set_container_uri "a-custom-registry.com/a-custom-repo/a-custom-image:v1.2.3@sha256:babafacecaca"
  _generate_templates

  run _extract_image

  assert_output --regexp '^a-custom-registry\.com/a-custom-repo/a-custom-image:v1\.2\.3@sha256:babafacecaca$'
}

should_use_its_own_registry_even_when_global_is_enabled() {
  _export_params "${@}"
  _enable_global_registry "the-global-registry.com"
  _set_container_uri "a-custom-registry.com/a-custom-image:v1.2.3"
  _generate_templates

  run _extract_image

  assert_output --regexp '^a-custom-registry\.com/a-custom-image:v1\.2\.3'
}

should_use_the_global_registry_when_it_doesnt_specify_one() {
  _export_params "${@}"
  _enable_global_registry "the-global-registry.com"
  _set_container_uri "a-custom-image:v1.2.3"
  _generate_templates

  run _extract_image

  assert_output --regexp '^the-global-registry\.com/a-custom-image:v1\.2\.3'
}

should_use_its_own_repository_even_when_global_is_enabled() {
  _export_params "${@}"
  _enable_global_repository "the-global-repository"
  _set_container_uri "a-custom-repository/a-custom-image:v1.2.3"
  _generate_templates

  run _extract_image

  assert_output --regexp '^a-custom-repository/a-custom-image:v1\.2\.3'
}

should_use_the_global_repository_when_it_doesnt_specify_one() {
  _export_params "${@}"
  _enable_global_repository "the-global-repository"
  _set_container_uri "a-custom-image:v1.2.3"
  _generate_templates

  run _extract_image

  assert_output --regexp '^the-global-repository/a-custom-image:v1\.2\.3'
}

should_use_the_global_repository_with_its_own_registry() {
  _export_params "${@}"
  _enable_global_repository "the-global-repository"
  _set_container_uri "my-own-registry.com/a-custom-image:v1.2.3"
  _generate_templates

  run _extract_image

  assert_output --regexp '^my-own-registry\.com/the-global-repository/a-custom-image:v1\.2\.3'
}

should_use_the_global_registry_with_its_own_repository() {
  _export_params "${@}"
  _enable_global_registry "the-global-registry.com"
  _set_container_uri "my-own-repository/a-custom-image:v1.2.3"
  _generate_templates

  run _extract_image

  assert_output --regexp '^the-global-registry\.com/my-own-repository/a-custom-image:v1\.2\.3'
}

should_allow_overwriting_the_tag_fragment_only() {
  _export_params "${@}"
  _set_container_uri ":v1.2.3"
  _generate_templates

  run _extract_image

  assert_output --regexp '^[^:]+:v1\.2\.3'
}

should_allow_overwriting_the_tag_and_sha_fragments_only() {
  _export_params "${@}"
  _set_container_uri ":v1.2.3@sha256:babafacecaca"
  _generate_templates

  run _extract_image

  assert_output --regexp '^[^:]+:v1\.2\.3@sha256:babafacecaca'
}

should_not_set_the_image_field_if_only_sha_is_specified() {
  _export_params "${@}"
  _set_container_uri "@sha256:babafacecaca"
  _generate_templates

  local num_appears
  num_appears="$(_extract_image | grep -o "babafacecaca" | wc -l)"

  assert [ "$num_appears" == "1" ]
}

_export_params() {
  export _image_property="${1}"
  export _container_name="${2}"
  export _template_file="${_templates_output}/${3}"
}

_set_container_uri() {
  yq.set sc ".images.${_image_property}" "\"${1}\""
}

_enable_global_registry() {
  yq.set sc .images.global.registry.enabled 'true'
  yq.set sc .images.global.registry.uri "\"${1}\""
}

_enable_global_repository() {
  yq.set sc .images.global.repository.enabled 'true'
  yq.set sc .images.global.repository.uri "\"${1}\""
}

_generate_templates() {
  helmfile -e service_cluster "${_helmfile_selector}" -f "${ROOT}/helmfile.d" -q template --output-dir-template "${_templates_output}"
}

_extract_image() {
  yq '.spec.template.spec.containers[] | select(.name == "'"${_container_name}"'") | .image' <"${_template_file}"
}
