#!/usr/bin/env bash

set -euo pipefail

export ANSIBLE_STDOUT_CALLBACK=yaml

echo "This script will install all requirements"
echo "Enter your password to start the install"

if [ "${#}" -ge 2 ] && [ "${2}" = "--user" ]; then
  export CK8S_INSTALL_PATH="${CK8S_INSTALL_PATH:-"${HOME}/bin"}"
  ansible-playbook -e 'ansible_python_interpreter=/usr/bin/python3' --ask-become-pass roles/get-requirements.yaml
else
  if [ "${#}" -ge 2 ] && [ "${2}" = "--become" ]; then
    ansible-playbook -e 'ansible_python_interpreter=/usr/bin/python3' --become --become-user root roles/get-requirements.yaml
  else
    ansible-playbook -e 'ansible_python_interpreter=/usr/bin/python3' --ask-become-pass --become --become-user root roles/get-requirements.yaml
  fi
fi
