#!/usr/bin/env bash

set -euo pipefail

root_path="$(readlink -f "$(dirname "${0}")/../")"

export ANSIBLE_STDOUT_CALLBACK=yaml

echo "This script will install all requirements"
echo "Enter your password to start the install"

if [ "${#}" -ge 1 ] && [ "${1}" = "--user" ]; then
  export CK8S_INSTALL_PATH="${CK8S_INSTALL_PATH:-"${HOME}/bin"}"
  ansible-playbook -e 'ansible_python_interpreter=/usr/bin/python3' --ask-become-pass "${root_path}/roles/get-requirements.yaml"
else
  if [ "${#}" -ge 1 ] && [ "${1}" = "--no-pass" ]; then
    ansible-playbook -e 'ansible_python_interpreter=/usr/bin/python3' --become --become-user root "${root_path}/roles/get-requirements.yaml"
  else
    ansible-playbook -e 'ansible_python_interpreter=/usr/bin/python3' --ask-become-pass --become --become-user root "${root_path}/roles/get-requirements.yaml"
  fi
fi
