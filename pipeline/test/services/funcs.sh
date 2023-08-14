#!/bin/bash
LOGGING=${LOGGING:-""}
PIPELINE=${PIPELINE:-false}
if [ -z "$PIPELINE" ]
then
    RETRY_COUNT=6
    RETRY_WAIT=10
else
    RETRY_COUNT=24
    RETRY_WAIT=10
fi

# Args:
#   1. kind
#   2. namespace
#   3. name of resource
function testResourceExistence {
    if kubectl get "$1" -n "$2" "$3" &> /dev/null
    then
        echo -n -e "\texists ✔"; SUCCESSES=$((SUCCESSES+1))
        return 0
    else
        echo -n -e "\tmissing ❌"; FAILURES=$((FAILURES+1))
        return 1
    fi
}

# Makes dataset smaller for optimization
# Args:
#   1. kind
function getStatus() {
    kind="${1}"
    jsonData=$(kubectl get "${kind}" --all-namespaces -o json)
    lessData=$(echo "${jsonData}" |
        jq '.items[] |
            {kind: .kind , name: .metadata.name , namespace: .metadata.namespace ,
            status: .status.readyReplicas , replicas: .status.replicas ,
            numberReady: .status.numberReady , desiredNumberScheduled: .status.desiredNumberScheduled}')
    echo "${lessData}"
}

# Args:
#   1. kind
#   2. namespace
#   3. name of resource
function testResourceExistenceFast {
    kind="${1}"
    namespace="${2}"
    currentResource="${3}"
    simpleData="${4}"
    activeResourceStatus=$(echo "${simpleData}" |
        jq -r --arg name "${currentResource}" --arg namespace "${namespace}" --arg kind "${kind}" '. |
            select(.name==$name and .namespace==$namespace and .kind==$kind) |
            .status')

    echo -n "${currentResource}"
    if [[ -z "${activeResourceStatus}" ]]; then
        echo -n -e "\texists ❌"; FAILURES=$((FAILURES+1))
        echo -e "\tready ❌"; FAILURES=$((FAILURES+1))
    else
        echo -n -e "\texists ✔"
        resourceReplicaCompare "${kind}" "${namespace}" "${currentResource}" "${simpleData}"
    fi
}

# This function checks if the amount of replicas for a deployment, daemonset or statefulset are correct
# Args:
#   1. kind
#   2. namespace
#   3. name of resource
#   4. jsonData
function resourceReplicaCompare() {
    kind="${1}"
    namespace="${2}"
    resourceName="${3}"
    simpleData="${4}"
    retriesLeft="${RETRY_COUNT}"
    while [[ "${retriesLeft}" -gt 0 ]]; do
        if [[ "${kind}" == "Deployment" || "${kind}" == "StatefulSet" ]]; then
            activeResourceStatus=$(echo "${simpleData}" |
                jq -r --arg name "${resourceName}" --arg kind "${kind}" '. |
                    select(.kind==$kind and .name==$name) |
                    .status')

            desiredResourceStatus=$(echo "${simpleData}" |
                jq -r --arg name "${resourceName}" --arg kind "${kind}" '. |
                    select(.kind==$kind and .name==$name) |
                    .replicas')
        # JSON data structure for daemonsets is different from deployments and statefulsets,
        # can not check amount of replicas in the exact same way
        elif [[ "${kind}" == "DaemonSet" ]]; then
            activeResourceStatus=$(echo "${simpleData}" |
                jq -r --arg name "${resourceName}" --arg kind "${kind}" '. |
                    select(.kind==$kind and .name==$name) |
                    .numberReady')

            desiredResourceStatus=$(echo "${simpleData}" |
                jq -r --arg name "${resourceName}" --arg kind "${kind}" '. |
                    select(.kind==$kind and .name==$name) |
                    .desiredNumberScheduled')
        fi

        if [[ "${activeResourceStatus}" == "${desiredResourceStatus}" ]]; then
            echo -e "\tready ✔"; SUCCESSES=$((SUCCESSES+1))
            if [ "$LOGGING" == "--logging-enabled" ]; then
              writeLog "${namespace}" "${resourceName}" "Pod"
              writeLog "${namespace}" "${resourceName}" "${kind}"
              writeEvent "${namespace}" "${resourceName}" "Pod"
            fi
            return
        else
            sleep "${RETRY_WAIT}"
            retriesLeft=$((retriesLeft-1))
            # refresh jsonData
            simpleData="$(getStatus "${kind}")"
        fi
    done

    echo -e "\tready ❌"; FAILURES=$((FAILURES+1))
    DEBUG_OUTPUT+=$(kubectl get "${kind}" -n "${namespace}" "${resourceName}" -o json)
    if [  "$LOGGING" == "--logging-enabled" ]; then
      writeLog "${namespace}" "${resourceName}" "Pod"
      writeLog "${namespace}" "${resourceName}" "${kind}"
      writeEvent "${namespace}" "${resourceName}" "Pod"
    fi
}

# This function is required for statefulsets with update strategy OnDelete
# since `kubectl rollout status` doesn't work for them.
# Args:
#   1. namespace
#   2. name of statefulset
function testStatefulsetStatusByPods {
    REPLICAS=$(kubectl get statefulset -n "$1" "$2" -o jsonpath="{.status.replicas}")

    for replica in $(seq 0 $((REPLICAS - 1))); do
        POD_NAME=$2-$replica
        if ! kubectl wait -n "$1" --for=condition=ready pod "$POD_NAME" --timeout=60s > /dev/null; then
            echo -n -e "\tnot ready ❌"; FAILURES=$((FAILURES+1))
            DEBUG_OUTPUT+="$(kubectl get statefulset -n "$1" "$2" -o json)"
            if [ "$LOGGING" == "--logging-enabled" ]; then
              writeLog "${1}" "${2}" "Pod"
              writeLog "${1}" "${2}" "${kind}"
              writeEvent "${1}" "${2}" "Pod"
            fi
            return
        fi
    done
    echo -n -e "\tready ✔"; SUCCESSES=$((SUCCESSES+1))
}

# Args:
#   1. namespace
#   2. name of job
#   3. Wait time for job to finish before marking failed
function testJobStatus {
    if kubectl wait --for=condition=complete --timeout="$3" -n "$1" job/"$2" > /dev/null; then
      echo -n -e "\tcompleted ✔"; SUCCESSES=$((SUCCESSES+1))
    else
      echo -n -e "\tnot completed ❌"; FAILURES=$((FAILURES+1))
      DEBUG_OUTPUT+=$(kubectl get -n "$1" job "$2" -o json)
    fi
    if [ "$LOGGING" == "--logging-enabled" ]; then
      logJob "${1}" "${2}"
    fi
}

# Args:
#   1. namespace
#   2. name
function logCronJob {
    writeEvent "${1}" "${2}" "CronJob"
    logJob "${1}" "${2}"
}

# Args:
#   1. namespace
#   2. name
function logJob {
    writeLog "${1}" "${2}" "Job"
    writeEvent "${1}" "${2}" "Job"
    writeEvent "${1}" "${2}" "Pod"
}

LOGSFOLDER="logs"
EVENTSFOLDER="events"

# This function writes logs to file for specified <kind>
# Args:
#   1. namespace
#   2. name
#   3. kind
function writeLog {
    if [ -z "$PIPELINE" ]
    then
        return
    fi

    NAMESPACE=$1
    NAME=$2
    KIND=$3
    NAMES=$(kubectl get "$KIND" -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name | grep "$NAME" | tail -n +1)
    mapfile -t NAMESLIST <<< "$NAMES"

    mkdir -p "./$LOGSFOLDER/$CLUSTER/$KIND/$NAMESPACE"
    for NAME in "${NAMESLIST[@]}"
    do
        FILE="./$LOGSFOLDER/$CLUSTER/$KIND/$NAMESPACE/$NAME.log"
        if [[ ! -f "$FILE" ]]; then
            touch "$FILE"
            kubectl -n "$NAMESPACE" logs "$KIND"/"$NAME" --all-containers=true > "$FILE" 2>&1
        fi
    done
}

# This function writes events to file for specified <kind>
# Args:
#   1. namespace
#   2. name
#   3. kind
function writeEvent {
    if [ -z "$PIPELINE" ]
    then
        return
    fi

    NAMESPACE=$1
    NAME=$2
    KIND=$3
    NAMES=$(kubectl get "$KIND" -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name | grep "$NAME" | tail -n +1)
    mapfile -t NAMESLIST <<< "$NAMES"

    mkdir -p "./$EVENTSFOLDER/$CLUSTER/$KIND/$NAMESPACE"
    for NAME in "${NAMESLIST[@]}"
    do
        FILE="./$EVENTSFOLDER/$CLUSTER/$KIND/$NAMESPACE/$NAME.event"
        if [[ ! -f "$FILE" ]]; then
            touch "$FILE"
            DATA=$(kubectl get event -n "${NAMESPACE}" --field-selector involvedObject.kind="${KIND}",involvedObject.name="${NAME}" -o json)
            MESSAGES=$(echo "${DATA}" | jq -r '.items | map(.message) | .[]')
            echo "$MESSAGES" > "$FILE"
        fi
    done
}

# Args:
#   1. Name of endpoint to print
#   2. url
#   3. (optional) username and password, <username>:<password>
function testEndpoint {
    echo -e "Testing $1 endpoint"

    retries="${RETRY_COUNT}"
    while [ ${retries} -gt 0 ]; do
        args=(
            --connect-timeout 20
            --max-time 60
            -ksIL
            -o /dev/null
            -X GET
            -w "%{http_code}"
        )
        [ -n "${3}" ] && args+=(-u "${3}")

        RES=$(curl "${args[@]}" "${2}")
        [[ $RES == "200" || $RES == "401" ]] && break

        sleep "${RETRY_WAIT}"
        retries=$((retries-1))
    done

    if [[ $RES == "200" || $RES == "401" ]]
    then echo "success ✔"; SUCCESSES=$((SUCCESSES+1))
    else echo "failure ❌"; FAILURES=$((FAILURES+1))
    fi
}

# Args:
#   1. Name of endpoint to print
#   2. url
#   3. expected HTTP response code
function testEndpointProtected {
    echo -e "Testing if $1 endpoint is protected"

    retries="${RETRY_COUNT}"
    while [ ${retries} -gt 0 ]; do
        args=(
            --connect-timeout 20
            --max-time 60
            -ksI
            -o /dev/null
            -X GET
            -w "%{http_code}"
        )

        RES=$(curl "${args[@]}" "${2}")
        [[ $RES == "${3}" ]] && break

        sleep "${RETRY_WAIT}"
        retries=$((retries-1))
    done

    if [[ $RES == "${3}" ]]
    then echo "success ✔"; SUCCESSES=$((SUCCESSES+1))
    else echo "failure ❌"; FAILURES=$((FAILURES+1))
    fi
}
