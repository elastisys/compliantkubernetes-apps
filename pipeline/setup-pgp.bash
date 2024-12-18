#!/usr/bin/env bash

set -eu -o pipefail

: "${PGP_KEY:?Missing PGP_KEY}"
: "${PGP_PASSPHRASE:?Missing PGP_PASSPHRASE}"

echo "${PGP_PASSPHRASE}" |
  gpg --pinentry-mode loopback --passphrase-fd 0 --import \
    <(echo "${PGP_KEY}")

echo allow-preset-passphrase >~/.gnupg/gpg-agent.conf
gpg-connect-agent reloadagent /bye

keys=$(gpg --list-keys --with-colons --with-keygrip)
keygrip=$(echo "${keys}" | awk -F: '$1 == "grp" {print $10;}' | tail -n1)

echo "${PGP_PASSPHRASE}" |
  /usr/lib/gnupg2/gpg-preset-passphrase --preset "${keygrip}"
