#!/usr/bin/env bash

# Helpers to manage gpg for tests

# Generates a temporary key, not intended for direct use
gpg.auto_generate_key() {
  gpg --batch --generate-key <<EOF
Key-Type: RSA
Key-Length: 4096
Name-Real: Compliant Kubernetes / Apps / Tests
Name-Email: support@elastisys.com
Expire-Date: 1d
%no-protection
%transient-key
%commit
EOF
}

# Creates a temporary gpg home and generates a temporary key
# CK8S_PGP_FP will be set with the fingerprint
gpg.setup() {
  GNUPGHOME="$(mktemp --directory)"
  export GNUPGHOME

  local n
  for n in $(seq 3); do
    # Retry as gpg-agent might not reliably start
    if gpg.auto_generate_key; then
      break;
    fi
    echo "failed to generate gpg key try ${n}" >&2
    n="0"
  done

  if [[ "${n}" == "0" ]]; then
    exit 1
  fi

  CK8S_PGP_FP="$(gpg --list-secret-keys --with-colons | grep -A1 '^sec' | grep '^fpr' | awk -F: '{print $10}')"
  export CK8S_PGP_FP
}

# Deletes the temporary gpg home
gpg.teardown() {
  rm -rf "${GNUPGHOME}"
}
