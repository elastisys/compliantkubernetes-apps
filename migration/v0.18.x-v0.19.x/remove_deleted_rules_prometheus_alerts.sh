#!/bin/bash

set -eo pipefail

./bin/ck8s ops helmfile sc -f helmfile -l app=prometheus-alerts -i apply

./bin/ck8s ops helmfile wc -f helmfile -l app=prometheus-alerts -i apply
