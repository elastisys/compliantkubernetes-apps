#!/usr/bin/env bash

# Args:
#   1. verb
#   2. resource
#   3. namespace
#   4. user
function testCanUserDoInNamespace {
    echo -n "$4 $1 $2 in $3"
    if kubectl auth can-i "$1" "$2" -n "$3" --as "$4" > /dev/null 2>&1;
    then echo -e "\tauthorized ✔"; SUCCESSES=$((SUCCESSES+1))
    else
        echo -e "\tnot authorized ❌"; FAILURES=$((FAILURES+1))
    fi
}

# Args:
#   1. verb
#   2. resource
#   3. user
function testCanUserDo {
    echo -n -e "$3 $1 $2"
    if kubectl auth can-i "$1" "$2" --as "$3" > /dev/null 2>&1;
    then echo -e "\tauthorized ✔"; SUCCESSES=$((SUCCESSES+1))
    else
        echo -e "\tnot authorized ❌"; FAILURES=$((FAILURES+1))
    fi
}

# Args:
#   1. verb
#   2. resource
#   3. namespace
#   4. user
function testCannotUserDoInNamespace {
    echo -n "$4 $1 $2 in $3"
    if kubectl auth can-i "$1" "$2" -n "$3" --as "$4" > /dev/null 2>&1;
    then echo -e "\tauthorized ❌"; FAILURES=$((FAILURES+1))
    else
        echo -e "\tnot authorized ✔"; SUCCESSES=$((SUCCESSES+1))
    fi
}

# Args:
#   1. verb
#   2. resource
#   3. user
function testCannotUserDo {
    echo -n -e "$3 $1 $2"
    if kubectl auth can-i "$1" "$2" --as "$3" > /dev/null 2>&1;
    then echo -e "\tauthorized ❌"; FAILURES=$((FAILURES+1))
    else
        echo -e "\tnot authorized ✔"; SUCCESSES=$((SUCCESSES+1))
    fi
}

echo
echo
echo "Testing user RBAC"
echo "====================="

user_namespaces=$(yq r "$CONFIG_FILE" 'user.namespaces[*]')
user_admin_users=$(yq r "$CONFIG_FILE" 'user.adminUsers[*]')

for user in ${user_admin_users}; do
    testCanUserDo "get" "node" "$user"
    testCanUserDo "get" "namespace" "$user"
    testCannotUserDo "drain" "node" "$user"
    testCannotUserDo "create" "namespace" "$user"
done

VERBS=(
    create
    delete
)
RESOURCES=(
    deployments
)

for user in ${user_admin_users}; do
    for namespace in ${user_namespaces}; do
        for resource in "${RESOURCES[@]}"; do
            for verb in "${VERBS[@]}"; do
                testCanUserDoInNamespace "$verb" "$resource" "$namespace" "$user"
            done
        done
    done
done

VERBS=(
    create
    delete
    patch
    update
)
RESOURCES=(
    deployments
    daemonset
    statefulset
    secrets
)
CK8S_NAMESPACES=(
    cert-manager
    ck8sdash
    default
    falco
    fluentd
    kube-system
    monitoring
    nginx-ingress
    velero
)

for user in ${user_admin_users}; do
    for namespace in "${CK8S_NAMESPACES[@]}"; do
        for resource in "${RESOURCES[@]}"; do
            for verb in "${VERBS[@]}"; do
                testCannotUserDoInNamespace "$verb" "$resource" "$namespace" "$user"
            done
        done
    done
done

FLUENTD_VERBS=(
    patch
)
FLUENTD_RESOURCES=(
    configmaps/fluentd-extra-config
    configmaps/fluentd-extra-plugins
)

for user in ${user_admin_users}; do
    for resource in "${FLUENTD_RESOURCES[@]}"; do
        for verb in "${FLUENTD_VERBS[@]}"; do
            testCanUserDoInNamespace "$verb" "$resource" "fluentd" "$user"
        done
    done
done

if [[ $ENABLE_USER_ALERTMANAGER == "true" ]]
then
    ALERTMANAGER_SECRET_VERBS=(
        update
    )
    ALERTMANAGER_SECRET_RESOURCES=(
        secret/alertmanager-alertmanager
        secret/user-alertmanager-auth
    )

    for user in ${user_admin_users}; do
        for resource in "${ALERTMANAGER_SECRET_RESOURCES[@]}"; do
            for verb in "${ALERTMANAGER_SECRET_VERBS[@]}"; do
                testCanUserDoInNamespace "$verb" "$resource" "monitoring" "$user"
            done
        done
    done

    ALERTMANAGER_SECRET_VERBS=(
        create
        delete
    )
    ALERTMANAGER_SECRET_RESOURCES=(
        secret/alertmanager-alertmanager
        secret/user-alertmanager-auth
    )

    for user in ${user_admin_users}; do
        for resource in "${ALERTMANAGER_SECRET_RESOURCES[@]}"; do
            for verb in "${ALERTMANAGER_SECRET_VERBS[@]}"; do
                testCannotUserDoInNamespace "$verb" "$resource" "monitoring" "$user"
            done
        done
    done

    ALERTMANAGER_ROLEBINDING_VERBS=(
        create
    )
    ALERTMANAGER_ROLEBINDING_RESOURCES=(
        rolebinding/alertmanager-configurer
    )

    for user in ${user_admin_users}; do
        for resource in "${ALERTMANAGER_ROLEBINDING_RESOURCES[@]}"; do
            for verb in "${ALERTMANAGER_ROLEBINDING_VERBS[@]}"; do
                testCanUserDoInNamespace "$verb" "$resource" "monitoring" "$user"
            done
        done
    done
fi
