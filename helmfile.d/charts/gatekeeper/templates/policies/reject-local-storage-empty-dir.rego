package k8srejectlocalstorageemptydir
import future.keywords.in

# violation if volume has no medium.
violation[{"msg": msg}] {
    volume := get_volumes[_]
    missing(volume.emptyDir, "medium")
    not check_volume_in_annotation(get_metadata, volume)
    not check_pod_annotation(get_metadata)
    msg := sprintf("The volume <%v> emptyDir is using local storage emptyDir. This can prevent autoscaler from scaling down a node where this is running. Read more about this and possible solutions at https://elastisys.io/welkin/user-guide/safeguards/enforce-no-local-storage-emptydir/",[volume])
}

# violation if medium is not Memory.
violation[{"msg": msg}] {
    volume := get_volumes[_]
    volume.emptyDir.medium != "Memory"
    not check_volume_in_annotation(get_metadata, volume)
    not check_pod_annotation(get_metadata)
    msg := sprintf("The volume <%v> emptyDir is using local storage emptyDir. This can prevent autoscaler from scaling down a node where this is running. Read more about this and possible solutions at https://elastisys.io/welkin/user-guide/safeguards/enforce-no-local-storage-emptydir/",[volume])
}

# Get volumes for "Pods"
get_volumes = res {
    input.review.object.kind == "Pod"
    res := input.review.object.spec.volumes
}

# Get volumes for resources that use pod templates.
get_volumes = res {
    kinds := [
        "Deployment",
        "StatefulSet",
        "DaemonSet",
        "ReplicaSet",
        "Job",
        "ReplicationController"
    ]
    input.review.object.kind == kinds[_]

    res := input.review.object.spec.template.spec.volumes
}

# Get volumes for "CronJobs"
get_volumes = res {
    input.review.object.kind == "CronJob"
    res := input.review.object.spec.jobTemplate.spec.template.spec.volumes
}

# Get metadata for "Pods"
get_metadata = res {
    input.review.object.kind == "Pod"
    res := input.review.object.metadata
}

# Get metadata for resources that use pod templates.
get_metadata = res {
    kinds := [
        "Deployment",
        "StatefulSet",
        "DaemonSet",
        "ReplicaSet",
        "Job",
        "ReplicationController"
    ]
    input.review.object.kind == kinds[_]

    res := input.review.object.spec.template.metadata
}

# Get metadata for "CronJobs"
get_metadata = res {
    input.review.object.kind == "CronJob"
    res := input.review.object.spec.jobTemplate.spec.template.metadata
}

# Field missing if it does not exist in the object
missing(obj, field) {
    not obj[field]
}

check_volume_in_annotation(metadata, volume) {
    some annotation_key, annotation_value in metadata.annotations
    annotation_key == input.parameters.volumeAnnotation

    split(annotation_value, ",")[_] == volume.name
}

check_pod_annotation(metadata) {
    metadata.annotations[input.parameters.podAnnotation] == "true"
}
