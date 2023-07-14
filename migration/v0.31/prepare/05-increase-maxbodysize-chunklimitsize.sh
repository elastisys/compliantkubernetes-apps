#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if ! yq_null sc .opensearch.ingress.maxbodysize; then
  log_info "- check if opensearch ingress maxbodysize is smaller then 32m"
  size=$(yq4 '.opensearch.ingress.maxbodysize | sub("m","")' "${CK8S_CONFIG_PATH}/sc-config.yaml")
  if ((size < 32)); then
    yq_remove sc .opensearch.ingress
  else
    log_info "- opensearch ingress maxbodysize is $size, will not remove it"
  fi
fi

if ! yq_null wc .fluentd.forwarder.buffer.chunkLimitSize; then
  log_info "- check if fluentd forwarder chunk size is smaller then 8MB or 8M"
  size=$(yq4 ' .fluentd.forwarder.buffer.chunkLimitSize | sub("(MB)|(M)","")' "${CK8S_CONFIG_PATH}/wc-config.yaml")
  if ((size < 8)); then
    yq_remove wc .fluentd.forwarder.buffer.chunkLimitSize
    if yq_check wc .fluentd.forwarder.buffer {}; then
      yq_remove wc .fluentd.forwarder.buffer
    fi
  else
    log_info "- fluentd forwarder chunk size is $size, will not remove it"
  fi
fi
