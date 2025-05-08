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

  export target_template="${CK8S_CONFIG_PATH}/sc-images-templates"
}

teardown_file() {
  env.teardown
  gpg.teardown
}

@test "the controller DaemonSet should have an image" {
  _generate_templates

  assert [ "$(_extract_controller_image)" != "" ]
}

@test "the controller DaemonSet should use our image" {
  yq.set sc .images.ingressNginxChart.controller '"a-custom-controller-image"'

  _generate_templates

  run _extract_controller_image

  assert_output --regexp '^a-custom-controller-image.*$'
}

@test "the controller DaemonSet should use our image and tag" {
  yq.set sc .images.ingressNginxChart.controller '"a-custom-controller-image:v1.2.3"'

  _generate_templates

  run _extract_controller_image

  assert_output --regexp '^a-custom-controller-image:v1\.2\.3$'
}

@test "the controller DaemonSet should use our image, tag and digest" {
  yq.set sc .images.ingressNginxChart.controller '"a-custom-controller-image:v1.2.3@sha256:babafacecaca"'

  _generate_templates

  run _extract_controller_image

  assert_output --regexp '^a-custom-controller-image:v1\.2\.3@sha256:babafacecaca$'
}

@test "the controller DaemonSet should use our repository, image, tag and digest" {
  yq.set sc .images.ingressNginxChart.controller '"a-custom-repo/a-custom-controller-image:v1.2.3@sha256:babafacecaca"'

  _generate_templates

  run _extract_controller_image

  assert_output --regexp '^a-custom-repo/a-custom-controller-image:v1\.2\.3@sha256:babafacecaca$'
}

@test "the controller DaemonSet should use our registry, repository, image, tag and digest" {
  yq.set sc .images.ingressNginxChart.controller '"a-custom-registry.com/a-custom-repo/a-custom-controller-image:v1.2.3@sha256:babafacecaca"'

  _generate_templates

  run _extract_controller_image

  assert_output --regexp '^a-custom-registry\.com/a-custom-repo/a-custom-controller-image:v1\.2\.3@sha256:babafacecaca$'
}

@test "the controller DaemonSet should use its own registry, even when global is enabled" {
  yq.set sc .images.global.registry.enabled 'true'
  yq.set sc .images.global.registry.uri '"the-global-registry.com"'
  yq.set sc .images.ingressNginxChart.controller '"a-custom-registry.com/a-custom-controller-image:v1.2.3"'

  _generate_templates

  run _extract_controller_image

  assert_output --regexp '^a-custom-registry\.com/a-custom-controller-image:v1\.2\.3'
}

@test "the controller DaemonSet should use the global registry when it doesn't specify one" {
  yq.set sc .images.global.registry.enabled 'true'
  yq.set sc .images.global.registry.uri '"the-global-registry.com"'
  yq.set sc .images.ingressNginxChart.controller '"a-custom-controller-image:v1.2.3"'

  _generate_templates

  run _extract_controller_image

  assert_output --regexp '^the-global-registry\.com/a-custom-controller-image:v1\.2\.3'
}

@test "the controller DaemonSet should use its own repository, even when global is enabled" {
  yq.set sc .images.global.repository.enabled 'true'
  yq.set sc .images.global.repository.uri '"the-global-repository"'
  yq.set sc .images.ingressNginxChart.controller '"a-custom-repository/a-custom-controller-image:v1.2.3"'

  _generate_templates

  run _extract_controller_image

  assert_output --regexp '^a-custom-repository/a-custom-controller-image:v1\.2\.3'
}

@test "the controller DaemonSet should use the global repository when it doesn't specify one" {
  yq.set sc .images.global.repository.enabled 'true'
  yq.set sc .images.global.repository.uri '"the-global-repository"'
  yq.set sc .images.ingressNginxChart.controller '"a-custom-controller-image:v1.2.3"'

  _generate_templates

  run _extract_controller_image

  assert_output --regexp '^the-global-repository/a-custom-controller-image:v1\.2\.3'
}

@test "the controller DaemonSet should use the global repository with its own registry" {
  yq.set sc .images.global.repository.enabled 'true'
  yq.set sc .images.global.repository.uri '"the-global-repository"'
  yq.set sc .images.ingressNginxChart.controller '"my-own-registry.com/a-custom-controller-image:v1.2.3"'

  _generate_templates

  run _extract_controller_image

  assert_output --regexp '^my-own-registry\.com/the-global-repository/a-custom-controller-image:v1\.2\.3'
}

@test "the controller DaemonSet should use the global registry with its own repository" {
  yq.set sc .images.global.registry.enabled 'true'
  yq.set sc .images.global.registry.uri '"the-global-registry.com"'
  yq.set sc .images.ingressNginxChart.controller '"my-own-repository/a-custom-controller-image:v1.2.3"'

  _generate_templates

  run _extract_controller_image

  assert_output --regexp '^the-global-registry\.com/my-own-repository/a-custom-controller-image:v1\.2\.3'
}

_generate_templates() {
  helmfile -e service_cluster -lapp=ingress-nginx -f "${ROOT}/helmfile.d" -q template --output-dir-template "${target_template}"
}

_extract_controller_image() {
  yq '.spec.template.spec.containers[] | select(.name == "controller") | .image' <"${target_template}/ingress-nginx/templates/controller-daemonset.yaml"
}

@test "the controller DaemonSet should allow overwriting the tag fragment only" {
  yq.set sc .images.ingressNginxChart.controller '":v1.2.3"'

  _generate_templates

  run _extract_controller_image

  assert_output --regexp '^registry.k8s.io/ingress-nginx/controller-chroot:v1\.2\.3'
}

@test "the controller DaemonSet should allow overwriting the tag and sha fragments only" {
  yq.set sc .images.ingressNginxChart.controller '":v1.2.3@sha256:babafacecaca"'

  _generate_templates

  run _extract_controller_image

  assert_output --regexp '^registry.k8s.io/ingress-nginx/controller-chroot:v1\.2\.3@sha256:babafacecaca'
}
