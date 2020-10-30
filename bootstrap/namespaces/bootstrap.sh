#!/usr/bin/env bash

set -euo pipefail

environment=$1

helmfile -f "${namespaces_path:?Missing namespaces path}/helmfile/helmfile.yaml" \
    -e "${environment}" template  | kubectl apply -f -
