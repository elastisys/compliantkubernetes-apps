#!/bin/bash

here="$(dirname "$(readlink -f "$0")")"
NAMESPACE="ck8s-integration-test"

setup_test() {
    kubectl create -f "${here}/ck8s-integration-test.yaml"
}

cleanup() {
    kubectl delete -f "${here}/ck8s-integration-test.yaml"
}

do_test() {
    url="${1}"
    # Check status code
    status_code=$(curl --silent -o /dev/null -w "%{http_code}" "${url}")

    if [[ "${status_code}" != "200" ]]; then
        echo -e "\treachable ❌"
        echo
        echo "Debug output of relevant resources:"
        echo
        kubectl -n ${NAMESPACE} describe deploy test
        kubectl -n ${NAMESPACE} describe pod -l app=test
        kubectl -n ${NAMESPACE} describe svc test
        exit 1
    else
        echo -e "\treachable ✔";
    fi
}

test_deploy() {
    # Deploy a simple nginx container and check that it starts sucessfully
    echo -n "Testing deployment"
    kubectl -n ${NAMESPACE} wait --for=condition=Available deploy/test \
        --timeout=5m &> /dev/null
    {
        kubectl -n ${NAMESPACE} port-forward deploy/test 8080:8080 &
        PF_PID=$!
        sleep 3 # It takes a littel while for the port-forward to activate.
    } &> /dev/null

    # Check status code
    do_test "localhost:8080"
    kill "${PF_PID}"; wait "${PF_PID}" 2>/dev/null
}

test_loadbalancer() {
    # Create a LoadBalancer service and expose an nginx deployment through it
    echo -n "Waiting 15x10s for external IP..."
    external_ip=""
    for i in {1..15}
    do
        external_ip=$(kubectl -n ${NAMESPACE} get svc test \
            -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
        if [ -z "${external_ip}" ]
        then
            echo -n " ${i}"
            sleep 10
        else
            echo " ✔"
            break
        fi
    done

    echo -n "Testing deployment through LoadBalancer"
    do_test "${external_ip}"
}

setup_test
test_deploy
[ "$CLOUD_PROVIDER" = "citycloud" ] && test_loadbalancer
cleanup
