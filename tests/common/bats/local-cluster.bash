#!/usr/bin/env bash

declare lib
declare scripts

declares() {
  lib="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
  scripts="$(dirname "$(dirname "$(dirname "${lib}")")")/scripts"
}

declares

# shellcheck source=tests/common/bats/env.bash
source "${lib}/env.bash"
# shellcheck source=tests/common/bats/gpg.bash
source "${lib}/gpg.bash"
# shellcheck source=tests/common/bats/yq.bash
source "${lib}/yq.bash"

# Usage: local_cluster.setup <config-flavour> <domain>
local_cluster.setup() {
  declares
  env.setup
  gpg.setup

  mkdir -p "${CK8S_CONFIG_PATH}/.state"

  "${scripts}/local-cluster.sh" config apps-tests "${@}"
}

# Usage: local_cluster.create <sc|wc> <local-cluster-profile>
local_cluster.create() {
  declares
  "${scripts}/local-cluster.sh" create "apps-tests-${1}" "${@:2}"
}

# Usage: local_cluster.delete <sc|wc>
local_cluster.delete() {
  declares
  CK8S_AUTO_APPROVE=true "${scripts}/local-cluster.sh" delete "apps-tests-${1}"
}

local_cluster.teardown() {
  declares
  env.teardown
  gpg.teardown
}

local_cluster.configure_selfsigned() {
  yq.set 'common' '.global.issuer' '"selfsigned"'
  yq.set 'common' '.global.verifyTls' 'false'

  yq.set 'common' '.issuers.extraIssuers' '[{ "apiVersion": "cert-manager.io/v1", "kind": "ClusterIssuer", "metadata": { "name": "selfsigned" }, "spec": { "selfSigned": {}}}]'

  yq.set 'common' '.issuers.letsencrypt.prod.email' '"admin@example.com"'
  yq.set 'common' '.issuers.letsencrypt.staging.email' '"admin@example.com"'
}

local_cluster.configure_node_local_dns() {
  declares
  "${scripts}/local-cluster.sh" setup node-local-dns
}
