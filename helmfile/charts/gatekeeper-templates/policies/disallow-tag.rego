package k8sdisallowedtags

# For regular containers
violation[{"msg": msg}] {

    container := get_containers[_]

    tags := [forbid | tag = input.parameters.tags[_] ; forbid = endswith(container.image, concat(":", ["", tag]))]
    any(tags)
    msg := sprintf("container <%v> uses a disallowed tag <%v>; disallowed tags are %v", [container.name, container.image, input.parameters.tags])
}

violation[{"msg": msg}] {

    container := get_containers[_]

    tag := [contains(container.image, ":")]
    not all(tag)
    msg := sprintf("container <%v> didn't specify an image tag <%v>", [container.name, container.image])
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

    tags := [forbid | tag = input.parameters.tags[_] ; forbid = endswith(container.image, concat(":", ["", tag]))]
    any(tags)
    msg := sprintf("container <%v> uses a disallowed tag <%v>; disallowed tags are %v", [container.name, container.image, input.parameters.tags])
}

violation[{"msg": msg}] {

    container := get_init_containers[_]

    tag := [contains(container.image, ":")]
    not all(tag)
    msg := sprintf("container <%v> didn't specify an image tag <%v>", [container.name, container.image])
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
