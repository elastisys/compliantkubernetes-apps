#!/usr/bin/env bash

set -euo pipefail

environment=$1

# Somewhat ugly, but Helm will not support labeling namespaces
# https://github.com/helm/helm/issues/3503
helmfile -f "${namespaces_path:?Missing namespaces path}/helmfile/helmfile.yaml" \
    -e "${environment}" template  | kubectl apply -f -
