#!/bin/bash
here="$(dirname "$(readlink -f "$0")")"
source "${here}/../../bin/common.bash"

: "${secrets[kube_config_sc]:?Missing service cluster kubeconfig}"
: "${secrets[kube_config_wc]:?Missing workload cluster kubeconfig}"

sc_issuer_namespaces='dex elastic-system kube-system monitoring ck8sdash harbor'
wc_issuer_namespaces='kube-system monitoring ck8sdash'

echo "Deleting issuers in sc..."
for ns in $sc_issuer_namespaces
do
  echo "In namespace ${ns}:"
  with_kubeconfig "${secrets[kube_config_sc]}" kubectl -n "${ns}" delete issuer letsencrypt-prod letsencrypt-staging
done

echo "Deleting issuers in wc..."
for ns in $wc_issuer_namespaces
do
  echo "In namespace ${ns}:"
  with_kubeconfig "${secrets[kube_config_wc]}" kubectl -n "${ns}" delete issuer letsencrypt-prod letsencrypt-staging
done
