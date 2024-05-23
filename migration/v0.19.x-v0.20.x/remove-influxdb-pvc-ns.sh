#!/usr/bin/env bash

set -euo pipefail

./bin/ck8s ops kubectl sc delete pvc influxdb-data-influxdb-0 -n influxdb-prometheus
./bin/ck8s ops kubectl sc delete ns influxdb-prometheus
