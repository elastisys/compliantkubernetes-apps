#!/bin/sh
set -e

validate_harbor() {
    echo "testing curl address ${ENDPOINT}"
    exists=$(curl -k "${ENDPOINT}"/projects/1 | jq '.code') || {
        echo "ERROR L.${LINENO} - Harbor url ${ENDPOINT}/projects/1 cannot be reached."
        exit 1
    }
    if [ -z "$exists" ]; then
        echo "ERROR - Harbor url ${ENDPOINT}/projects/1 did not return any code (probably cannot be reached)"
        exit 1
    fi
    echo "${exists}"
}

delete_library_project() {
    echo Removing project library from harbor
    # Curl will return status 500 even though it successfully removed the project.
    curl -k -X DELETE -u admin:"${HARBOR_PASSWORD}" "${ENDPOINT}"/projects/1 >/dev/null
}

create_new_private_default_project() {
    echo "Creating new private project default"
    curl -k -X POST -u admin:"${HARBOR_PASSWORD}" "${ENDPOINT}"/projects --header 'Content-Type: application/json' --header 'Accept: application/json' --data '{
                "project_name": "default",
                "metadata": {
                    "public": "0",
                    "enable_content_trust": "false",
                    "prevent_vul": "false",
                    "severity": "low",
                    "auto_scan": "true"
                }
            }'
    echo "Private default project created"
}

init_harbor_state() {

    exists=$(validate_harbor)

    echo "Setting up initial harbor state"
    if [ "$exists" != "404" ]; then
        name=$(curl -k -X GET "${ENDPOINT}"/projects/1 | jq '.name')

        if [ "$name" = "\"library\"" ]; then
            delete_library_project
            create_new_private_default_project
        fi
    else
        echo "Harbor already created default project"
    fi
}

configure_OIDC() {
    echo "Configuring oidc support"
    err=$(curl -k -X PUT "${ENDPOINT}/configurations" \
        -u admin:"${HARBOR_PASSWORD}" \
        -H "accept: application/json" \
        -H "Content-Type: application/json" \
        -d "{ \"primary_auth_mode\": true,
              \"oidc_verify_cert\": ${OIDC_VERIFY_CERT},
              \"auth_mode\": \"oidc_auth\",
              \"self_registration\": false,
              \"oidc_scope\": \"${OIDC_SCOPE}\",
              \"oidc_name\": \"dex\",
              \"oidc_client_id\": \"harbor\",
              \"oidc_endpoint\": \"${OIDC_ENDPOINT}\",
              \"oidc_client_secret\": \"${OIDC_CLIENT_SECRET}\",
              \"oidc_admin_group\": \"${OIDC_ADMIN_GROUP_NAME}\",
              \"oidc_groups_claim\": \"${OIDC_GROUP_CLAIM_NAME}\"}")
    if [ -n "$err" ]; then
        echo "ERROR when configuring oidc: $err"
        exit 1
    fi
}

configure_GC() {
    echo "Configuring GC"

    if [ "${GC_FORCE_CONFIGURE}" = "false" ]; then
        res=$(curl -k -X GET -w "%{http_code}" "${ENDPOINT}/system/gc/schedule" \
            -u admin:"${HARBOR_PASSWORD}")

        # shellcheck disable=SC3057
        http_code="${res:${#res}-3}"

        if [ "${http_code}" != "200" ]; then
            echo "Failed to check if GC is configured: ${res}"
            exit 1
        fi

        if [ ${#res} -ne 3 ]; then
            echo "GC already configured"
            return
        fi
    fi

    err=$(curl -k -X PUT "${ENDPOINT}/system/gc/schedule" \
        -u admin:"${HARBOR_PASSWORD}" \
        -H "accept: application/json" \
        -H "Content-Type: application/json" \
        -d "{ \"parameters\": {},
              \"schedule\": {
                \"cron\": \"${GC_SCHEDULE}\",
                \"type\": \"Custom\"
              }
            }")
    if [ -n "$err" ]; then
        echo "ERROR when configuring GC: $err"
        exit 1
    fi
}

init_harbor_state
configure_OIDC
if [ "${GC_ENABLED}" = "true" ]; then
    configure_GC
fi

echo "Harbor initialized"
