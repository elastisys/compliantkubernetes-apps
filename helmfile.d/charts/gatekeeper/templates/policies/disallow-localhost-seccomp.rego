package k8sdisallowlocalhostseccomp

# For pods

# Violation if pods use Localhost seccompProfile
violation[{"msg": msg}] {

    object := get_pods

    object.spec.securityContext.seccompProfile.type == "Localhost"

    msg := sprintf("The %v named <%v> uses Localhost seccompProfile. Elastisys Welkin® does not allow the use of Localhost secompProfile.", [object.kind, object.metadata.name])
}

# Get "Pods"
get_pods = res {
    input.review.object.kind == "Pod"
    res := input.review.object
}

# For deployments, statefulsets, daemonsets, replicasets, jobs, replicationcontrollers

# Violation if resources that uses podTemplates use Localhost seccompProfile
violation[{"msg": msg}] {

    object := get_objects

    object.spec.template.spec.securityContext.seccompProfile.type == "Localhost"

    msg := sprintf("The %v named <%v> uses Localhost seccompProfile in the pod template. Elastisys Welkin® does not allow the use of Localhost secompProfile.", [object.kind, object.metadata.name])
}

# Get resources that use pod templates.
get_objects = res {
    kinds := [
        "Deployment",
        "StatefulSet",
        "DaemonSet",
        "ReplicaSet",
        "Job",
        "ReplicationController"
    ]
    input.review.object.kind == kinds[_]

    res := input.review.object
}

# For cronjobs

# Violation cronjobs use Localhost seccompProfile
violation[{"msg": msg}] {

    object := get_cronjobs

    object.spec.jobTemplate.spec.template.spec.securityContext.seccompProfile.type == "Localhost"

    msg := sprintf("The %v named <%v> uses Localhost seccompProfile in the pod template. Elastisys Welkin® does not allow the use of Localhost secompProfile.", [object.kind, object.metadata.name])
}

# Get "CronJobs"
get_cronjobs = res {
    input.review.object.kind == "CronJob"
    res := input.review.object
}

# For regular containers

# Violation if containers use Localhost seccompProfile
violation[{"msg": msg}] {

    container := get_containers[_]

    container.securityContext.seccompProfile.type == "Localhost"

    msg := sprintf("The container named <%v> uses Localhost seccompProfile. Elastisys Welkin® does not allow the use of Localhost secompProfile.", [container.name])
}

# Get containers for "Pods"
get_containers = res {
    pod := get_pods

    res := pod.spec.containers
}

# Get containers for resources that use pod templates.
get_containers = res {
    object := get_objects

    res := object.spec.template.spec.containers
}

# Get containers for "CronJobs"
get_containers = res {
    cronjob := get_cronjobs

    res := cronjob.spec.jobTemplate.spec.template.spec.containers
}

# For init containers

# Violation if init containers use Localhost seccompProfile
violation[{"msg": msg}] {

    container := get_init_containers[_]

    container.securityContext.seccompProfile.type == "Localhost"

    msg := sprintf("The container named <%v> uses Localhost seccompProfile. Elastisys Welkin® does not allow the use of Localhost secompProfile.", [container.name])
}

# Get init containers for "Pods"
get_init_containers = res {
    pod := get_pods

    res := pod.spec.initContainers
}

# Get init containers for resources that use pod templates.
get_init_containers = res {
    object := get_objects

    res := object.spec.template.spec.initContainers
}

# Get init containers for "CronJobs"
get_init_containers = res {
    cronjob := get_cronjobs

    res := cronjob.spec.jobTemplate.spec.template.spec.initContainers
}

# For ephemeral containers

# Violation if ephemeral containers use Localhost seccompProfile
violation[{"msg": msg}] {

    container := get_ephemeral_containers[_]

    container.securityContext.seccompProfile.type == "Localhost"

    msg := sprintf("The container named <%v> uses Localhost seccompProfile. Elastisys Welkin® does not allow the use of Localhost secompProfile.", [container.name])
}

# Get ephemeral containers for "Pods"
get_ephemeral_containers = res {
    pod := get_pods

    res := pod.spec.ephemeralContainers
}

# Get ephemeral containers for resources that use pod templates.
get_ephemeral_containers = res {
    object := get_objects

    res := object.spec.template.spec.ephemeralContainers
}

# Get ephemeral containers for "CronJobs"
get_ephemeral_containers = res {
    cronjob := get_cronjobs

    res := cronjob.spec.jobTemplate.spec.template.spec.ephemeralContainers
}
