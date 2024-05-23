#!/usr/bin/env bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

for cluster in sc wc; do
  config="${CK8S_CONFIG_PATH}/${cluster}-config.yaml"
  cert_type=$(yq r "$config" 'global.certType')

  issuer="letsencrypt-$cert_type"
  if [ "$cert_type" = prod ]; then
    verify_tls=true
  else
    verify_tls=false
  fi
  prod_email=$(yq r "$config" 'letsencrypt.prod.email')
  staging_email=$(yq r "$config" 'letsencrypt.staging.email')

  if [ -z "$cert_type" ]; then
    echo "Error: 'global.certType' is missing in $config."
    echo "Cannot migrate to 'global.issuer' and 'global.verifyTls'."
    exit 1
  elif [ -z "$prod_email" ]; then
    echo "Error: 'letsencrypt.prod.email' is missing in $config."
    echo "Cannot migrate to 'issuers.letsencrypt' configuration."
    exit 1
  elif [ -z "$staging_email" ]; then
    echo "Error: 'letsencrypt.staging.email' is missing in $config."
    echo "Cannot migrate to 'issuers.letsencrypt' configuration."
    exit 1
  fi

  echo "Migrating configuration in file $config"

  yq w -i "$config" 'global.issuer' "$issuer"
  yq w -i "$config" 'global.verifyTls' "$verify_tls"

  cat <<EOF >> "$config"
issuers:
  letsencrypt:
    enabled: true
    prod:
      email: "$prod_email"
    staging:
      email: "$staging_email"
  extraIssuers: []
EOF

  echo "You can now remove 'global.certType' and 'letsencrypt.*' from $config."
  echo "Just be careful to NOT remove 'issuers.letsencrypt.*'."
done
