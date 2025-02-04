package k8sdisallowedtags

# For regular containers
violation[{"msg": msg}] {

    container := get_containers[_]

    tags := [forbid | tag = input.parameters.tags[_] ; forbid = endswith(container.image, concat(":", ["", tag]))]
    any(tags)
    msg := sprintf("The container named <%v> uses the :latest tag. Elastisys Welkin® requires all images to have explicit tags. Read more at https://elastisys.io/welkin/user-guide/safeguards/enforce-no-latest-tag/", [container.name])
}

violation[{"msg": msg}] {

    container := get_containers[_]

    tag := [contains(container.image, ":")]
    not all(tag)
    msg := sprintf("The container named <%v> didn't specify an image tag. Elastisys Welkin® requires all images to have tags to avoid the implicit :latest tag. Read more at https://elastisys.io/welkin/user-guide/safeguards/enforce-no-latest-tag/", [container.name])
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
    msg := sprintf("The container named <%v> uses the :latest tag. Elastisys Welkin® requires all images to have explicit tags. Read more at https://elastisys.io/welkin/user-guide/safeguards/enforce-no-latest-tag/", [container.name])
}

violation[{"msg": msg}] {

    container := get_init_containers[_]

    tag := [contains(container.image, ":")]
    not all(tag)
    msg := sprintf("The container named <%v> didn't specify an image tag. Elastisys Welkin® requires all images to have tags to avoid the implicit :latest tag. Read more at https://elastisys.io/welkin/user-guide/safeguards/enforce-no-latest-tag/", [container.name])
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
