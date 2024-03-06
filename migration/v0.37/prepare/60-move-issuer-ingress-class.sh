#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

log_info "Moving issuer ingress class keys"
log_info "- Operating on common-config"

if ! yq_null common .issuers.letsencrypt.prod.solvers; then
  log_info "- move: .issuers.letsencrypt.prod.solvers[].http01.ingress.class to: .issuers.letsencrypt.prod.solvers[].http01.ingress.ingressClassName"
  yq4 -i "with(.issuers.letsencrypt.prod.solvers[].http01.ingress | select(has(\"class\")); .ingressClassName = .class | del(.class))" "${CK8S_CONFIG_PATH}/common-config.yaml"
fi

if ! yq_null common .issuers.letsencrypt.staging.solvers; then
  log_info "- move: .issuers.letsencrypt.staging.solvers[].http01.ingress.class to: .issuers.letsencrypt.staging.solvers[].http01.ingress.ingressClassName"
  yq4 -i "with(.issuers.letsencrypt.staging.solvers[].http01.ingress | select(has(\"class\")); .ingressClassName = .class | del(.class))" "${CK8S_CONFIG_PATH}/common-config.yaml"
fi

if ! yq_null common .issuers.extraIssuers; then
  log_info "- move: .issuers.extraIssuers[].spec.acme.solvers[].http01.ingress.class to: .issuers.extraIssuers[].spec.acme.solvers[].http01.ingress.ingressClassName"
  yq4 -i "with(.issuers.extraIssuers[].spec.acme.solvers[].http01.ingress | select(has(\"class\")); .ingressClassName = .class | del(.class))" "${CK8S_CONFIG_PATH}/common-config.yaml"
fi

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  log_info "- Operating on sc-config"

  if ! yq_null sc .issuers.letsencrypt.prod.solvers; then
    log_info "- move: .issuers.letsencrypt.prod.solvers[].http01.ingress.class to: .issuers.letsencrypt.prod.solvers[].http01.ingress.ingressClassName"
    yq4 -i "with(.issuers.letsencrypt.prod.solvers[].http01.ingress | select(has(\"class\")); .ingressClassName = .class | del(.class))" "${CK8S_CONFIG_PATH}/sc-config.yaml"
  fi

  if ! yq_null sc .issuers.letsencrypt.staging.solvers; then
    log_info "- move: .issuers.letsencrypt.staging.solvers[].http01.ingress.class to: .issuers.letsencrypt.staging.solvers[].http01.ingress.ingressClassName"
    yq4 -i "with(.issuers.letsencrypt.staging.solvers[].http01.ingress | select(has(\"class\")); .ingressClassName = .class | del(.class))" "${CK8S_CONFIG_PATH}/sc-config.yaml"
  fi

  if ! yq_null sc .issuers.extraIssuers; then
    log_info "- move: .issuers.extraIssuers[].spec.acme.solvers[].http01.ingress.class to: .issuers.extraIssuers[].spec.acme.solvers[].http01.ingress.ingressClassName"
    yq4 -i "with(.issuers.extraIssuers[].spec.acme.solvers[].http01.ingress | select(has(\"class\")); .ingressClassName = .class | del(.class))" "${CK8S_CONFIG_PATH}/sc-config.yaml"
  fi

fi

if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  log_info "- Operating on wc-config"

  if ! yq_null wc .issuers.letsencrypt.prod.solvers; then
    log_info "- move: .issuers.letsencrypt.prod.solvers[].http01.ingress.class to: .issuers.letsencrypt.prod.solvers[].http01.ingress.ingressClassName"
    yq4 -i "with(.issuers.letsencrypt.prod.solvers[].http01.ingress | select(has(\"class\")); .ingressClassName = .class | del(.class))" "${CK8S_CONFIG_PATH}/wc-config.yaml"
  fi

  if ! yq_null wc .issuers.letsencrypt.staging.solvers; then
    log_info "- move: .issuers.letsencrypt.staging.solvers[].http01.ingress.class to: .issuers.letsencrypt.staging.solvers[].http01.ingress.ingressClassName"
    yq4 -i "with(.issuers.letsencrypt.staging.solvers[].http01.ingress | select(has(\"class\")); .ingressClassName = .class | del(.class))" "${CK8S_CONFIG_PATH}/wc-config.yaml"
  fi

  if ! yq_null wc .issuers.extraIssuers; then
    log_info "- move: .issuers.extraIssuers[].spec.acme.solvers[].http01.ingress.class to: .issuers.extraIssuers[].spec.acme.solvers[].http01.ingress.ingressClassName"
    yq4 -i "with(.issuers.extraIssuers[].spec.acme.solvers[].http01.ingress | select(has(\"class\")); .ingressClassName = .class | del(.class))" "${CK8S_CONFIG_PATH}/wc-config.yaml"
  fi

fi
