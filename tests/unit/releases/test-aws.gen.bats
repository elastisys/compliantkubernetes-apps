#!/usr/bin/env bats

# Generated from tests/unit/releases/template.bats.gotmpl

# bats file_tags=static,aws

setup_file() {
  load "../../common/lib"
  load "../../common/lib/env"
  load "../../common/lib/gpg"
  load "script"

  gpg.setup
  env.setup

  env.init prod aws kubespray

  helmfile_template_releases sc
  helmfile_template_releases wc
}

setup() {
  load "../../common/lib"
  load "script"

  common_setup
}

teardown_file() {
  env.teardown
  gpg.teardown
}

@test "releases have constraint templates through needs - aws - service cluster" {
  # used filter: a constraint's kind...
  # created filter: should exist in a constraint's templates spec
  releases_have_through_needs sc \
    'select(.apiVersion == "constraints.gatekeeper.sh/v1beta1") | .kind | "ConstraintTemplate/" + .' \
    'select(.kind == "ConstraintTemplate") | .spec.crd.spec.names.kind | "ConstraintTemplate/" + .'
}

@test "releases have constraint templates through needs - aws - workload cluster" {
  # used filter: a constraint's kind...
  # created filter: should exist in a constraint's templates spec
  releases_have_through_needs wc \
    'select(.apiVersion == "constraints.gatekeeper.sh/v1beta1") | .kind | "ConstraintTemplate/" + .' \
    'select(.kind == "ConstraintTemplate") | .spec.crd.spec.names.kind | "ConstraintTemplate/" + .'
}

@test "releases have custom resource definitions through needs - aws - service cluster" {
  # used filter: a custom resource's kind...
  # created filter: should exist in a custom resource definition's templates spec
  releases_have_through_needs sc \
    'select(.apiVersion | test("^(.+\.k8s\.io/|apps/|batch/|policy/|constraints.gatekeeper.sh/|)v1.*") | not) | .kind | "CustomResourceDefinition/" + .' \
    'select(.kind == "CustomResourceDefinition") | .spec.names.kind | "CustomResourceDefinition/" + .'
}

@test "releases have custom resource definitions through needs - aws - workload cluster" {
  # used filter: a custom resource's kind...
  # created filter: should exist in a custom resource definition's templates spec
  releases_have_through_needs wc \
    'select(.apiVersion | test("^(.+\.k8s\.io/|apps/|batch/|policy/|constraints.gatekeeper.sh/|)v1.*") | not) | .kind | "CustomResourceDefinition/" + .' \
    'select(.kind == "CustomResourceDefinition") | .spec.names.kind | "CustomResourceDefinition/" + .'
}

@test "releases have namespaces through needs - aws - service cluster" {
  # used filter: a resource's namespace (except certain defaults)...
  # created filter: should exist
  releases_have_through_needs sc \
    '.metadata.namespace | select(. != "default" and . != "kube-system" and . != "rook-ceph") | "Namespace/" + .' \
    'select(.kind == "Namespace") | .metadata.name | "Namespace/" + .'
}

@test "releases have namespaces through needs - aws - workload cluster" {
  # used filter: a resource's namespace (except certain defaults)...
  # created filter: should exist
  releases_have_through_needs wc \
    '.metadata.namespace | select(. != "default" and . != "kube-system" and . != "rook-ceph") | "Namespace/" + .' \
    'select(.kind == "Namespace") | .metadata.name | "Namespace/" + .'
}

@test "releases with custom resources have validation on install disabled - aws - service cluster" {
  release_with_custom_resources_have_validation_on_install_disabled sc
}

@test "releases with custom resources have validation on install disabled - aws - workload cluster" {
  release_with_custom_resources_have_validation_on_install_disabled wc
}
