#!/usr/bin/env bats

# Generated from tests/unit/templates/releases.bats.gotmpl

# bats file_tags=static,releases,elastx

setup_file() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "gpg.bash"
  load_common "yq.bash"
  load "../templates/releases.bash"

  gpg.setup
  env.setup

  env.init elastx kubespray prod

  helmfile_template_releases sc
  helmfile_template_releases wc
}

setup() {
  load "../../bats.lib.bash"
  load_common "yq.bash"
  load "../templates/releases.bash"
}

teardown_file() {
  env.teardown
  gpg.teardown
}

@test "releases have constraint templates through needs - elastx - service cluster" {
  # used filter: a constraint's kind...
  # created filter: should exist in a constraint's templates spec
  releases_have_through_needs sc \
    'select(.apiVersion == "constraints.gatekeeper.sh/v1beta1") | .kind | "ConstraintTemplate/" + .' \
    'select(.kind == "ConstraintTemplate") | .spec.crd.spec.names.kind | "ConstraintTemplate/" + .'
}

@test "releases have constraint templates through needs - elastx - workload cluster" {
  # used filter: a constraint's kind...
  # created filter: should exist in a constraint's templates spec
  releases_have_through_needs wc \
    'select(.apiVersion == "constraints.gatekeeper.sh/v1beta1") | .kind | "ConstraintTemplate/" + .' \
    'select(.kind == "ConstraintTemplate") | .spec.crd.spec.names.kind | "ConstraintTemplate/" + .'
}

@test "releases have custom resource definitions through needs - elastx - service cluster" {
  # used filter: a custom resource's kind...
  # created filter: should exist in a custom resource definition's templates spec
  releases_have_through_needs sc \
    'select(.apiVersion | test("^(.+\.k8s\.io/|apps/|batch/|policy/|constraints.gatekeeper.sh/|)v1.*") | not) | .kind | "CustomResourceDefinition/" + .' \
    'select(.kind == "CustomResourceDefinition") | .spec.names.kind | "CustomResourceDefinition/" + .'
}

@test "releases have custom resource definitions through needs - elastx - workload cluster" {
  # used filter: a custom resource's kind...
  # created filter: should exist in a custom resource definition's templates spec
  releases_have_through_needs wc \
    'select(.apiVersion | test("^(.+\.k8s\.io/|apps/|batch/|policy/|constraints.gatekeeper.sh/|)v1.*") | not) | .kind | "CustomResourceDefinition/" + .' \
    'select(.kind == "CustomResourceDefinition") | .spec.names.kind | "CustomResourceDefinition/" + .'
}

@test "releases have namespaces through needs - elastx - service cluster" {
  # used filter: a resource's namespace (except certain defaults)...
  # created filter: should exist
  releases_have_through_needs sc \
    '.metadata.namespace | select(. != "default" and . != "kube-system" and . != "rook-ceph") | "Namespace/" + .' \
    'select(.kind == "Namespace") | .metadata.name | "Namespace/" + .'
}

@test "releases have namespaces through needs - elastx - workload cluster" {
  # used filter: a resource's namespace (except certain defaults)...
  # created filter: should exist
  releases_have_through_needs wc \
    '.metadata.namespace | select(. != "default" and . != "kube-system" and . != "rook-ceph") | "Namespace/" + .' \
    'select(.kind == "Namespace") | .metadata.name | "Namespace/" + .'
}

@test "releases with custom resources have validation on install disabled - elastx - service cluster" {
  release_with_custom_resources_have_validation_on_install_disabled sc
}

@test "releases with custom resources have validation on install disabled - elastx - workload cluster" {
  release_with_custom_resources_have_validation_on_install_disabled wc
}
