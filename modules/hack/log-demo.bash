#!/bin/bash

#
# fluentd-forwarder release difference: ./test.bash diff-main-template workload_cluster fluentd-forwarder
# fluentd-forwarder can be installed without opensearch credentials even though opensearch.enabled = true
#

set -euo pipefail

here="$(dirname "$(readlink -f "$0")")"

root="${here}/../.."

opensearch_hostname="opensearch.$(yq4 '.global.opsDomain' "${CK8S_CONFIG_PATH}/common-config.yaml")"

get_lb_ip() {
  lb_ip=$("${root}/bin/ck8s" ops kubectl sc get services -n ingress-nginx ingress-nginx-controller \
    --output jsonpath='{.status.loadBalancer.ingress[0].ip}')

  if [ -z "${lb_ip}" ]; then
    lb_hostname=$("${root}/bin/ck8s" ops kubectl sc get services -n ingress-nginx ingress-nginx-controller \
      --output jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    lb_ip="${lb_hostname%.nip.io}"
  fi

  echo "${lb_ip}"
}

ensure_ingress_dns() {
  while :; do
    dns_ip=$(dig +short "${opensearch_hostname}")
    lb_ip=$(get_lb_ip)

    [ "${dns_ip}" = "${lb_ip}" ] && break

    echo "${opensearch_hostname} points to: ${dns_ip}"
    echo "Actual loadbalancer IP is: ${lb_ip}"
    echo "Update the DNS record"

    sleep 1
  done
}

case "${1}" in
install-ingress)
  "${root}/bin/ck8s" ops helmfile sc apply -l name=issuers
  "${root}/bin/ck8s" ops helmfile sc apply -l name=ingress-nginx --include-transitive-needs
  ensure_ingress_dns
  "${root}/bin/ck8s" update-ips both apply || true
  "${root}/bin/ck8s" ops helmfile sc apply -l name=ingress-nginx --include-transitive-needs
  ;;
install-opensearch-deps)
  "${root}/bin/ck8s" ops helmfile sc apply -l netpol=service --include-transitive-needs
  "${root}/bin/ck8s" ops helmfile sc apply -l name=crossplane-provider-configs --include-transitive-needs
  "${root}/bin/ck8s" ops helmfile sc apply -l name=opensearch-secrets --include-transitive-needs
  "${root}/bin/ck8s" ops helmfile sc apply -l app=opensearch,policy=psp --include-transitive-needs
  ;;
install-opensearch)
  "${root}/bin/ck8s" ops helmfile sc apply -l name=module-opensearch
  "${root}/bin/ck8s" ops helmfile sc apply -l name=opensearch-securityadmin
  "${root}/bin/ck8s" ops helmfile sc apply -l name=opensearch-configurer
  ;;
uninstall-opensearch)
  "${root}/bin/ck8s" ops helmfile sc destroy -l name=opensearch-configurer
  "${root}/bin/ck8s" ops helmfile sc destroy -l name=opensearch-securityadmin
  "${root}/bin/ck8s" ops helmfile sc destroy -l name=module-opensearch
  ;;
install-fluentd-deps)
  "${root}/bin/ck8s" ops helmfile wc apply -l name=crossplane-provider-configs --include-transitive-needs
  "${root}/bin/ck8s" ops helmfile wc apply -l app=fluentd,policy=netpol --include-transitive-needs
  "${root}/bin/ck8s" ops helmfile wc apply -l app=fluentd,policy=psp --include-transitive-needs
  ;;
install-fluentd)
  "${root}/bin/ck8s" ops helmfile wc apply -l name=module-fluentd-forwarder
  ;;
uninstall-fluentd)
  "${root}/bin/ck8s" ops helmfile wc destroy -l name=module-fluentd-forwarder
  ;;
uninstall)
  "${root}/bin/ck8s" clean wc
  "${root}/bin/ck8s" clean sc
  ;;
esac
