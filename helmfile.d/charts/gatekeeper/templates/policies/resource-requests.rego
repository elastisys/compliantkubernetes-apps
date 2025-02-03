package k8sresourcerequests

# violation if container has no resource REQUESTS.
violation[{"msg": msg}] {
    container := get_containers[_]
    not container.resources.requests
    msg := sprintf("The container named <%v> has no resource requests. Welkin® requires resource requests to be set for all containers. Read more at https://elastisys.io/welkin/user-guide/safeguards/enforce-resources/", [container.name])
}

# violation if CPU REQUESTS is missing.
violation[{"msg": msg}] {
    container := get_containers[_]
    missing(container.resources.requests, "cpu")
    msg := sprintf("The container <%v> has no cpu request. Welkin® requires resource requests to be set for all containers. Read more at https://elastisys.io/welkin/user-guide/safeguards/enforce-resources/", [container.name])
}

# violation if MEMORY REQUESTS is missing.
violation[{"msg": msg}] {
    container := get_containers[_]
    missing(container.resources.requests, "memory")
    msg := sprintf("The container <%v> has no memory request. Welkin® requires resource requests to be set for all containers. Read more at https://elastisys.io/welkin/user-guide/safeguards/enforce-resources/", [container.name])
}

# Get containers for "Pods"
get_containers = res {
    input.review.object.kind == "Pod"
    res := input.review.object.spec.containers
}

# Get containers for resources that use pod templates.
get_containers = res {
    kinds := [
        "Deployment",
        "StatefulSet",
        "DaemonSet",
        "ReplicaSet",
        "Job",
        "ReplicationController"
    ]
    input.review.object.kind == kinds[_]

    res := input.review.object.spec.template.spec.containers
}

# Get containers for "CronJobs"
get_containers = res {
    input.review.object.kind == "CronJob"
    res := input.review.object.spec.jobTemplate.spec.template.spec.containers
}


# Field missing if it does not exist in the object
missing(obj, field) {
    not obj[field]
}
