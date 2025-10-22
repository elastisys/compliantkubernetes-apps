#!/usr/bin/env bash

set -eu -o pipefail

: "${PGP_PASSPHRASE:?Missing PGP_PASSPHRASE}"
: "${PGP_EMAIL:?Missing PGP_EMAIL}"
: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

gpg --batch --gen-key <<EOF
Key-Type: RSA
Key-Length: 4096
Name-Real: Elastisys Pipeline
Name-Email: ${PGP_EMAIL}
Expire-Date: 1d
Passphrase: ${PGP_PASSPHRASE}
EOF

echo allow-preset-passphrase >~/.gnupg/gpg-agent.conf
gpg-connect-agent reloadagent /bye

keys=$(gpg --list-keys --with-colons --with-keygrip)
keygrip=$(echo "${keys}" | awk -F: '$1 == "grp" {print $10;}' | tail -n1)
keyfpr=$(echo "${keys}" | awk -F: '$1 == "fpr" {print $10;}' | tail -n1)

echo "${PGP_PASSPHRASE}" |
  /usr/lib/gnupg2/gpg-preset-passphrase --preset "${keygrip}"

yq -i ".creation_rules[].pgp = \"$keyfpr\"" "${CK8S_CONFIG_PATH}/.sops.yaml"
