#!/usr/bin/env bash

# Helpers to manage gpg for tests

# Generates a temporary key, not intended for direct use
#
# NOTE: the short key length of 1024 bits has no serious security implications,
# as the generated keys are local, ephemeral and used for test purposes only.
gpg.auto_generate_key() {
  gpg --batch --generate-key <<EOF
Key-Type: RSA
Key-Length: 1024
Name-Real: Welkin / Apps / Tests / ${1}
Name-Email: support@elastisys.com
Expire-Date: 1d
%no-protection
%fast-random
%transient-key
%commit
EOF
}

gpg.auto_generate_key_retry() {
  local n
  for n in $(seq 3); do
    # Retry as gpg-agent might not reliably start
    if gpg.auto_generate_key "${1}"; then
      break
    fi
    echo "failed to generate gpg key try ${n}" >&2
    n="0"
  done

  if [[ "${n}" == "0" ]]; then
    exit 1
  fi
}

# Creates a temporary gpg home and generates a temporary key
# CK8S_PGP_FP will be set with the fingerprint
gpg.setup() {
  GNUPGHOME="$(mktemp --directory)"
  export GNUPGHOME

  gpg.auto_generate_key_retry "Key one"
  gpg.auto_generate_key_retry "Key two"

  CK8S_PGP_FP="$(gpg --list-secret-keys --with-colons | grep -A1 '^sec' | grep '^fpr' | awk -F: '{print $10}' | paste -sd "," -)"
  export CK8S_PGP_FP
}

# Deletes the temporary gpg home
gpg.teardown() {
  rm -rf "${GNUPGHOME}"
}
