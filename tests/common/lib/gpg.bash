#!/usr/bin/env bash

# Helpers to manage gpg for tests

# Creates a temporary gpg home and generates a temporary key
# CK8S_PGP_FP will be set with the fingerprint
gpg.setup() {
  GNUPGHOME="$(mktemp --directory)"
  export GNUPGHOME

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

  CK8S_PGP_FP="$(gpg --list-secret-keys --with-colons | grep -A1 '^sec' | grep '^fpr' | awk -F: '{print $10}')"
  export CK8S_PGP_FP
}

# Deletes the temporary gpg home
gpg.teardown() {
  rm -rf "${GNUPGHOME}"
}
