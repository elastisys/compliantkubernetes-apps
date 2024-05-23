#!/usr/bin/env bash

set -eo pipefail

./bin/ck8s ops helmfile sc -f helmfile -l app=grafana-ops destroy
