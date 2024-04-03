#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  log_info "operation on service cluster"
  # Check thanos.ruler.resources.limits.memory
  if ! yq_null sc .thanos.ruler.resources.limits.memory; then
    log_info "- check if thanos ruler memory limit is less than 300Mi"
    bytelimit=$(yq4 '.thanos.ruler.resources.limits.memory' "${CK8S_CONFIG_PATH}/sc-config.yaml" | LC_ALL=C numfmt --from=auto)
    if [ -n "$bytelimit" ] && ((bytelimit < 314572800)); then
      log_info "- increase the thanos ruler memory limit to 300Mi"
      yq4 -i '.thanos.ruler.resources.limits.memory = "300Mi"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    else
      log_info "- thanos ruler memory limit is greater or equal with 300Mi, will not update it"
    fi
  fi
  # Check thanos.storegateway.resources.limits.memory
  if ! yq_null sc .thanos.storegateway.resources.limits.memory; then
    log_info "- check if thanos storegateway memory limit is less than 2000Mi"
    bytelimit=$(yq4 '.thanos.storegateway.resources.limits.memory' "${CK8S_CONFIG_PATH}/sc-config.yaml" | LC_ALL=C numfmt --from=auto)
    if [ -n "$bytelimit" ] && ((bytelimit < 2097152000)); then
      log_info "- increase the thanos storegateway memory limit to 2000Mi"
      yq4 -i '.thanos.storegateway.resources.limits.memory = "2000Mi"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    else
      log_info "- thanos storegateway memory limit is greater or equal with 2000Mi, will not update it"
    fi
  fi
  # Check opensearch.exporter.resources.limits.memory:
  if ! yq_null sc .opensearch.exporter.resources.limits.memory; then
    log_info "- check if opensearch exporter memory limit is less than 300Mi"
    bytelimit=$(yq4 '.opensearch.exporter.resources.limits.memory' "${CK8S_CONFIG_PATH}/sc-config.yaml" | LC_ALL=C numfmt --from=auto)
    if [ -n "$bytelimit" ] && ((bytelimit < 314572800)); then
      log_info "- increase the opensearch exporter memory limit to 300Mi"
      yq4 -i '.opensearch.exporter.resources.limits.memory = "300Mi"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    else
      log_info "- opensearch exporter memory limit is greater or equal with 300Mi, will not update it"
    fi
  fi
  # Check falco.resources.limits.memory
  if ! yq_null sc .falco.resources.limits.memory; then
    log_info "- check if falco memory limit is less than 500Mi"
    bytelimit=$(yq4 '.falco.resources.limits.memory' "${CK8S_CONFIG_PATH}/sc-config.yaml" | LC_ALL=C numfmt --from=auto)
    if [ -n "$bytelimit" ] && ((bytelimit < 524288000)); then
      log_info "- increase the falco memory limit to 500Mi"
      yq4 -i '.falco.resources.limits.memory = "500Mi"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    else
      log_info "- falco memory limit is greater or equal with 500Mi, will not update it"
    fi
  fi
    # Check falco.falcoSidekick.resources.limits.memory
  if ! yq_null sc .falco.falcoSidekick.resources.limits.memory; then
    log_info "- check if falco.falcoSidekick memory limit is less than 250Mi"
    bytelimit=$(yq4 '.falco.falcoSidekick.resources.limits.memory' "${CK8S_CONFIG_PATH}/sc-config.yaml" | LC_ALL=C numfmt --from=auto)
    if [ -n "$bytelimit" ] && ((bytelimit < 262144000)); then
      log_info "- increase the falco.falcoSidekick memory limit to 250Mi"
      yq4 -i '.falco.falcoSidekick.resources.limits.memory = "250Mi"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    else
      log_info "- falco.falcoSidekick memory limit is greater or equal with 250Mi, will not update it"
    fi
  fi
  # Check falco.falcoExporter.resources.limits.memory
  if ! yq_null sc .falco.falcoExporter.resources.limits.memory; then
    log_info "- check if falco.falcoExporter memory limit is less than 50Mi"
    bytelimit=$(yq4 '.falco.falcoExporter.resources.limits.memory' "${CK8S_CONFIG_PATH}/sc-config.yaml" | LC_ALL=C numfmt --from=auto)
    if [ -n "$bytelimit" ] && ((bytelimit < 52428800)); then
      log_info "- increase the falco.falcoExporter memory limit to 50Mi"
      yq4 -i '.falco.falcoExporter.resources.limits.memory = "50Mi"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    else
      log_info "- falco.falcoExporter memory limit is greater or equal with 50Mi, will not update it"
    fi
  fi
  # Check kubeStateMetrics.resources.limits.memory
  if ! yq_null sc .kubeStateMetrics.resources.limits.memory; then
    log_info "- check if kubeStateMetrics memory limit is less than 300Mi"
    bytelimit=$(yq4 '.kubeStateMetrics.resources.limits.memory' "${CK8S_CONFIG_PATH}/sc-config.yaml" | LC_ALL=C numfmt --from=auto)
    if [ -n "$bytelimit" ] && ((bytelimit < 314572800)); then
      log_info "- increase the kubeStateMetrics memory limit to 300Mi"
      yq4 -i '.kubeStateMetrics.resources.limits.memory = "300Mi"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    else
      log_info "- kubeStateMetrics memory limit is greater or equal with 300Mi, will not update it"
    fi
  fi
  # Check opa.audit.resources.limits.memory
  if ! yq_null sc .opa.audit.resources.limits.memory; then
    log_info "- check if opa.audit memory limit is less than 500Mi"
    bytelimit=$(yq4 '.opa.audit.resources.limits.memory' "${CK8S_CONFIG_PATH}/sc-config.yaml" | LC_ALL=C numfmt --from=auto)
    if [ -n "$bytelimit" ] && ((bytelimit < 524288000)); then
      log_info "- increase the opa.audit memory limit to 500Mi"
      yq4 -i '.opa.audit.resources.limits.memory = "500Mi"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    else
      log_info "- opa.audit memory limit is greater or equal with 500Mi, will not update it"
    fi
  fi
  # Check opa.audit.resources.limits.cpu
  if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
    if ! yq_null wc .opa.audit.resources.limits.cpu; then
      size=$(yq4 '.opa.audit.resources.limits.cpu | select(. == "*m") | sub("m","")' "${CK8S_CONFIG_PATH}/sc-config.yaml")
      if [ -n "$size" ] && ((size < 750)); then
        log_info "- increase the opa audit cpu limit on sc to 750m"
        yq4 -i '.opa.audit.resources.limits.cpu = "750m"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
      fi
    fi
  fi
fi

# WC cluster
if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  log_info "operation on workload cluster"
  # Check fluentd.user.resources.limits.memory
  if ! yq_null wc .fluentd.user.resources.limits.memory; then
    log_info "- check if fluentd user memory limit is less than 1000Mi"
    bytelimit=$(yq4 '.fluentd.user.resources.limits.memory' "${CK8S_CONFIG_PATH}/wc-config.yaml" | LC_ALL=C numfmt --from=auto)
    if [ -n "$bytelimit" ] && ((bytelimit < 1048576000)); then
      log_info "- increase the fluentd user memory limit to 1000Mi"
      yq4 -i '.fluentd.user.resources.limits.memory = "1000Mi"' "${CK8S_CONFIG_PATH}/wc-config.yaml"
    else
      log_info "- fluentd user memory limit is greater or equal with 1000Mi, will not update it"
    fi
  fi
  # Check falco.resources.limits.memory
  if ! yq_null wc .falco.resources.limits.memory; then
    log_info "- check if falco memory limit is less than 500Mi"
    bytelimit=$(yq4 '.falco.resources.limits.memory' "${CK8S_CONFIG_PATH}/wc-config.yaml" | LC_ALL=C numfmt --from=auto)
    if [ -n "$bytelimit" ] && ((bytelimit < 524288000)); then
      log_info "- increase the falco memory limit to 500Mi"
      yq4 -i '.falco.resources.limits.memory = "500Mi"' "${CK8S_CONFIG_PATH}/wc-config.yaml"
    else
      log_info "- falco memory limit is greater or equal with 500Mi, will not update it"
    fi
  fi
  # Check falco.falcoSidekick.resources.limits.memory
  if ! yq_null wc .falco.falcoSidekick.resources.limits.memory; then
    log_info "- check if falco.falcoSidekick memory limit is less than 250Mi"
    bytelimit=$(yq4 '.falco.falcoSidekick.resources.limits.memory' "${CK8S_CONFIG_PATH}/wc-config.yaml" | LC_ALL=C numfmt --from=auto)
    if [ -n "$bytelimit" ] && ((bytelimit < 262144000)); then
      log_info "- increase the falco.falcoSidekick memory limit to 250Mi"
      yq4 -i '.falco.falcoSidekick.resources.limits.memory = "250Mi"' "${CK8S_CONFIG_PATH}/wc-config.yaml"
    else
      log_info "- falco.falcoSidekick memory limit is greater or equal with 250Mi, will not update it"
    fi
  fi
  # Check falco.falcoExporter.resources.limits.memory
  if ! yq_null wc .falco.falcoExporter.resources.limits.memory; then
    log_info "- check if falco.falcoExporter memory limit is less than 50Mi"
    bytelimit=$(yq4 '.falco.falcoExporter.resources.limits.memory' "${CK8S_CONFIG_PATH}/wc-config.yaml" | LC_ALL=C numfmt --from=auto)
    if [ -n "$bytelimit" ] && ((bytelimit < 52428800)); then
      log_info "- increase the falco.falcoExporter memory limit to 50Mi"
      yq4 -i '.falco.falcoExporter.resources.limits.memory = "50Mi"' "${CK8S_CONFIG_PATH}/wc-config.yaml"
    else
      log_info "- falco.falcoExporter memory limit is greater or equal with 50Mi, will not update it"
    fi
  fi
  # Check kubeStateMetrics.resources.limits.memory
  if ! yq_null wc .kubeStateMetrics.resources.limits.memory; then
    log_info "- check if kubeStateMetrics memory limit is less than 300Mi"
    bytelimit=$(yq4 '.kubeStateMetrics.resources.limits.memory' "${CK8S_CONFIG_PATH}/wc-config.yaml" | LC_ALL=C numfmt --from=auto)
    if [ -n "$bytelimit" ] && ((bytelimit < 314572800)); then
      log_info "- increase the kubeStateMetrics memory limit to 300Mi"
      yq4 -i '.kubeStateMetrics.resources.limits.memory = "300Mi"' "${CK8S_CONFIG_PATH}/wc-config.yaml"
    else
      log_info "- kubeStateMetrics memory limit is greater or equal with 300Mi, will not update it"
    fi
  fi
  # Check opa.audit.resources.limits.memory
  if ! yq_null wc .opa.audit.resources.limits.memory; then
    log_info "- check if opa.audit memory limit is less than 500Mi"
    bytelimit=$(yq4 '.opa.audit.resources.limits.memory' "${CK8S_CONFIG_PATH}/wc-config.yaml" | LC_ALL=C numfmt --from=auto)
    if [ -n "$bytelimit" ] && ((bytelimit < 524288000)); then
      log_info "- increase the opa.audit memory limit to 500Mi"
      yq4 -i '.opa.audit.resources.limits.memory = "500Mi"' "${CK8S_CONFIG_PATH}/wc-config.yaml"
    else
      log_info "- opa.audit memory limit is greater or equal with 500Mi, will not update it"
    fi
  fi
  # Check opa.audit.resources.limits.cpu
  if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
    if ! yq_null wc .opa.audit.resources.limits.cpu; then
      size=$(yq4 '.opa.audit.resources.limits.cpu | select(. == "*m") | sub("m","")' "${CK8S_CONFIG_PATH}/wc-config.yaml")
      if [ -n "$size" ] && ((size < 750)); then
        log_info "- increase the opa audit cpu limit on wc to 750m"
        yq4 -i '.opa.audit.resources.limits.cpu = "750m"' "${CK8S_CONFIG_PATH}/wc-config.yaml"
      fi
    fi
  fi
fi
