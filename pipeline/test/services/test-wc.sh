#!/bin/bash

SCRIPTS_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
if [[ ! -f $1 ]];then
    echo "ERROR: $1 is not a valid file"
    exit 1
fi

export CONFIG_FILE=$1
LOGGING="${3:-$2}"
SUCCESSES=0
FAILURES=0
DEBUG_OUTPUT=("")
DEBUG_PROMETHEUS_TARGETS=("")
export CLUSTER="WorkloadCluster"

# shellcheck source=pipeline/test/services/workload-cluster/testPodsReady.sh
source "${SCRIPTS_PATH}"/workload-cluster/testPodsReady.sh
# shellcheck source=pipeline/test/services/common/testPersistentVolumeClaims.sh
source "${SCRIPTS_PATH}"/common/testPersistentVolumeClaims.sh
# shellcheck source=pipeline/test/services/workload-cluster/testEndpoints.sh
source "${SCRIPTS_PATH}"/workload-cluster/testEndpoints.sh
# shellcheck source=pipeline/test/services/workload-cluster/testPrometheusTargets.sh
source "${SCRIPTS_PATH}"/workload-cluster/testPrometheusTargets.sh
# shellcheck source=pipeline/test/services/workload-cluster/testUserRbac.sh
source "${SCRIPTS_PATH}"/workload-cluster/testUserRbac.sh

echo -e "\nSuccesses: $SUCCESSES"
echo "Failures: $FAILURES"

if [ $FAILURES -gt 0 ] && [ "$LOGGING" == "--logging-enabled" ]
then
    echo "Something failed"
    echo
    echo "Logs from failed test resources"
    echo "==============================="
    echo
    echo "Exists in logs/WorkloadCluster/<kind>/<namespace>"
    echo
    echo "Events from failed test resources"
    echo "==============================="
    echo
    echo "Exists in events/WorkloadCluster/<kind>/<namespace>"
    echo
    echo "Json output of failed test resources"
    echo "===================================="
    echo
    echo "${DEBUG_OUTPUT[@]}" | jq .
    echo
    echo "Unhealthy/missing prometheus targets"
    echo "===================================="
    echo
    echo "${DEBUG_PROMETHEUS_TARGETS[@]}"
    echo
    exit 1
elif [ $FAILURES -gt 0 ]
then
    echo "Something failed"
    echo
    echo "Json output of failed test resources"
    echo "===================================="
    echo
    echo "${DEBUG_OUTPUT[@]}" | jq .
    echo
    echo "Unhealthy/missing prometheus targets"
    echo "===================================="
    echo
    echo "${DEBUG_PROMETHEUS_TARGETS[@]}"
    echo
    exit 1
fi

echo "All tests succeeded"
