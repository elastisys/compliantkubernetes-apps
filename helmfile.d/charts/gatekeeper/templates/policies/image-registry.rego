package k8sallowedrepos

# For regular containers
violation[{"msg": msg}] {

    container := get_containers[_]

    satisfied := [good | repo = input.parameters.repos[_] ; good = startswith(container.image, repo)]
    not any(satisfied)
    msg := sprintf("The container named <%v> does not have an allowed image registry <%v>, allowed registries are <%v>. Elastisys Welkin® requires that all images come from trusted registries. Read more at https://elastisys.io/welkin/user-guide/safeguards/enforce-trusted-registries/", [container.name, container.image, input.parameters.repos])
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

# For init containers
violation[{"msg": msg}] {

    container := get_init_containers[_]

    satisfied := [good | repo = input.parameters.repos[_] ; good = startswith(container.image, repo)]
    not any(satisfied)
    msg := sprintf("The initContainer named <%v> does not have an allowed image registry <%v>, allowed registries are <%v>. Elastisys Welkin® requires that all images come from trusted registries. Read more at https://elastisys.io/welkin/user-guide/safeguards/enforce-trusted-registries/", [container.name, container.image, input.parameters.repos])
}

# Get init containers for "Pods"
get_init_containers = res {
    input.review.object.kind == "Pod"
    res := input.review.object.spec.initContainers
}

# Get init containers for resources that use pod templates.
get_init_containers = res {
    kinds := [
        "Deployment",
        "StatefulSet",
        "DaemonSet",
        "ReplicaSet",
        "Job",
        "ReplicationController"
    ]
    input.review.object.kind == kinds[_]

    res := input.review.object.spec.template.spec.initContainers
}

# Get init containers for "CronJobs"
get_init_containers = res {
    input.review.object.kind == "CronJob"
    res := input.review.object.spec.jobTemplate.spec.template.spec.initContainers
}
