#!/usr/bin/env bash

set -euo pipefail

export ANSIBLE_STDOUT_CALLBACK=yaml

echo "This script will install all requirements"
echo "Enter your password to start the install"
ansible-playbook -e 'ansible_python_interpreter=/usr/bin/python3' --ask-become-pass --connection local --inventory 127.0.0.1, roles/get-requirements.yaml
