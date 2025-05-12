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

  export _target_template="${CK8S_CONFIG_PATH}/sc-images-templates"
  export _helmfile_selector="-lapp=ingress-nginx"

  export _container_name="controller"
  export _template_file="controller-daemonset.yaml"
  export _image_property="ingressNginxChart.controller"
}

teardown_file() {
  env.teardown
  gpg.teardown
}

@test "the container image should be set" {
  _generate_templates

  assert [ "$(_extract_image)" != "" ]
}

@test "the container image should use our image" {
  _set_container_uri "a-custom-image"
  _generate_templates
  run _extract_image

  assert_output --regexp '^a-custom-image.*$'
}

@test "the container image should use our image and tag" {
  _set_container_uri "a-custom-image:v1.2.3"
  _generate_templates
  run _extract_image

  assert_output --regexp '^a-custom-image:v1\.2\.3$'
}

@test "the container image should use our image, tag and digest" {
  _set_container_uri "a-custom-image:v1.2.3@sha256:babafacecaca"
  _generate_templates
  run _extract_image

  assert_output --regexp '^a-custom-image:v1\.2\.3@sha256:babafacecaca$'
}

@test "the container image should use our repository, image, tag and digest" {
  _set_container_uri "a-custom-repo/a-custom-image:v1.2.3@sha256:babafacecaca"
  _generate_templates
  run _extract_image

  assert_output --regexp '^a-custom-repo/a-custom-image:v1\.2\.3@sha256:babafacecaca$'
}

@test "the container image should use our registry, repository, image, tag and digest" {
  _set_container_uri "a-custom-registry.com/a-custom-repo/a-custom-image:v1.2.3@sha256:babafacecaca"
  _generate_templates
  run _extract_image

  assert_output --regexp '^a-custom-registry\.com/a-custom-repo/a-custom-image:v1\.2\.3@sha256:babafacecaca$'
}

@test "the container image should use its own registry, even when global is enabled" {
  _enable_global_registry "the-global-registry.com"
  _set_container_uri "a-custom-registry.com/a-custom-image:v1.2.3"
  _generate_templates
  run _extract_image

  assert_output --regexp '^a-custom-registry\.com/a-custom-image:v1\.2\.3'
}

@test "the container image should use the global registry when it doesn't specify one" {
  _enable_global_registry "the-global-registry.com"
  _set_container_uri "a-custom-image:v1.2.3"
  _generate_templates
  run _extract_image

  assert_output --regexp '^the-global-registry\.com/a-custom-image:v1\.2\.3'
}

@test "the container image should use its own repository, even when global is enabled" {
  _enable_global_repository "the-global-repository"
  _set_container_uri "a-custom-repository/a-custom-image:v1.2.3"
  _generate_templates
  run _extract_image

  assert_output --regexp '^a-custom-repository/a-custom-image:v1\.2\.3'
}

@test "the container image should use the global repository when it doesn't specify one" {
  _enable_global_repository "the-global-repository"
  _set_container_uri "a-custom-image:v1.2.3"
  _generate_templates
  run _extract_image

  assert_output --regexp '^the-global-repository/a-custom-image:v1\.2\.3'
}

@test "the container image should use the global repository with its own registry" {
  _enable_global_repository "the-global-repository"
  _set_container_uri "my-own-registry.com/a-custom-image:v1.2.3"
  _generate_templates
  run _extract_image

  assert_output --regexp '^my-own-registry\.com/the-global-repository/a-custom-image:v1\.2\.3'
}

@test "the container image should use the global registry with its own repository" {
  _enable_global_registry "the-global-registry.com"
  _set_container_uri "my-own-repository/a-custom-image:v1.2.3"
  _generate_templates
  run _extract_image

  assert_output --regexp '^the-global-registry\.com/my-own-repository/a-custom-image:v1\.2\.3'
}

@test "the container image should allow overwriting the tag fragment only" {
  _set_container_uri ":v1.2.3"
  _generate_templates
  run _extract_image

  assert_output --regexp '^[^:]+:v1\.2\.3'
}

@test "the container image should allow overwriting the tag and sha fragments only" {
  _set_container_uri ":v1.2.3@sha256:babafacecaca"
  _generate_templates
  run _extract_image

  assert_output --regexp '^[^:]+:v1\.2\.3@sha256:babafacecaca'
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
  helmfile -e service_cluster "${_helmfile_selector}" -f "${ROOT}/helmfile.d" -q template --output-dir-template "${_target_template}"
}

_extract_image() {
  yq '.spec.template.spec.containers[] | select(.name == "'"${_container_name}"'") | .image' <"${_target_template}/ingress-nginx/templates/${_template_file}"
}
