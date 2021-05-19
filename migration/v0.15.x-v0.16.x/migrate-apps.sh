#!/bin/bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

config="${CK8S_CONFIG_PATH}/sc-config.yaml"
secret="${CK8S_CONFIG_PATH}/secrets.yaml"
secret_tmp="${CK8S_CONFIG_PATH}/secrets_tmp.yaml"
sops_conf="${CK8S_CONFIG_PATH}/.sops.yaml"

# Fetch old variables
base_domain=$(yq r "$config" 'global.baseDomain')
dex_oidcProvider=$(yq r "$config" 'dex.oidcProvider')
declare -a dex_allowedDomains
# dex_allowedDomains=( $(yq r "$config" 'dex.allowedDomains[*]') )
mapfile -t dex_allowedDomains < <(yq r "$config" 'dex.allowedDomains[*]')
dex_insecureSkipEmailVerified=$(yq r "$config" 'dex.insecureSkipEmailVerified')
dex_insecureEnableGroups=$(yq r "$config" 'dex.insecureEnableGroups')
dex_redirect="https://dex.${base_domain}/callback"

update_script=$(mktemp -p /tmp update-script.XXXXXXXXXX.yaml)
cp "${here}/update-script.yaml" "${update_script}"

if [[ "${dex_oidcProvider}" == "google" ]]; then
  dex_clientID=$(sops -d --extract '["dex"]["googleClientID"]' "${secret}")
  dex_clientSecret=$(sops -d --extract '["dex"]["googleClientSecret"]' "${secret}")

  dex_id="google"
  dex_name="Google"
  dex_issuer="https://accounts.google.com"
elif [[ "${dex_oidcProvider}" == "okta" ]]; then
  dex_clientID=$(sops -d --extract '["dex"]["oktaClientID"]' "${secret}")
  dex_clientSecret=$(sops -d --extract '["dex"]["oktaClientSecret"]' "${secret}")

  dex_id="okta"
  dex_name="Okta"
  dex_issuer=$(sops -d --extract '["dex"]["issuer"]' "${secret}")

  yq w -i "${update_script}" '[0].value[0].config.insecureSkipEmailVerified' "${dex_insecureSkipEmailVerified}"
  yq w -i "${update_script}" '[0].value[0].config.insecureEnableGroups' "${dex_insecureEnableGroups}"
  yq w -i "${update_script}" '[0].value[0].config.scope[+]' "openid"
  yq w -i "${update_script}" '[0].value[0].config.scope[+]' "profile"
  yq w -i "${update_script}" '[0].value[0].config.scope[+]' "email"
  yq w -i "${update_script}" '[0].value[0].config.scope[+]' "groups"
  yq w -i "${update_script}" '[0].value[0].config.getUserInfo' "true"
elif [[ "${dex_oidcProvider}" == "aaa" ]]; then
  dex_clientID=$(sops -d --extract '["dex"]["aaaClientID"]' "${secret}")
  dex_clientSecret=$(sops -d --extract '["dex"]["aaaClientSecret"]' "${secret}")

  dex_id="aaa"
  dex_name="AAA"
  dex_issuer="https://asmp-test.a1.net/oauth2"

  yq w -i "${update_script}" '[0].value[0].config.insecureSkipEmailVerified' "true"
fi

yq w -i "${update_script}" '[0].value[0].id' "${dex_id}"
yq w -i "${update_script}" '[0].value[0].name' "${dex_name}"
yq w -i "${update_script}" '[0].value[0].config.issuer' "${dex_issuer}"
yq w -i "${update_script}" '[0].value[0].config.redirectURI' "${dex_redirect}"
yq w -i "${update_script}" '[0].value[0].config.clientID' "${dex_clientID}"
yq w -i "${update_script}" '[0].value[0].config.clientSecret' "${dex_clientSecret}"

for allowed_domain in "${dex_allowedDomains[@]}"; do
  yq w -i "${update_script}" '[0].value[0].config.hostedDomains[+]' "${allowed_domain}"
done

sops -d "${secret}" | \
  yq w -s "${update_script}" - | \
  yq d - 'dex.issuer' | \
  yq d - 'dex.googleClientID' | \
  yq d - 'dex.googleClientSecret' | \
  yq d - 'dex.oktaClientID' | \
  yq d - 'dex.oktaClientSecret' | \
  yq d - 'dex.aaaClientID' | \
  yq d - 'dex.aaaClientSecret' | \
  sops --config "${sops_conf}" --input-type=yaml --output-type=yaml -e /dev/stdin > "${secret_tmp}"

mv "${secret_tmp}" "${secret}"

yq d -i "$config" 'dex.oidcProvider'
yq d -i "$config" 'dex.allowedDomains'
yq d -i "$config" 'dex.insecureSkipEmailVerified'
yq d -i "$config" 'dex.insecureEnableGroups'

rm "${update_script}"
