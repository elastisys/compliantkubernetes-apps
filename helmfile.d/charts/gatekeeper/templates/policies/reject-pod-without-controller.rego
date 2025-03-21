package k8srejectpodwithoutcontroller

metadata := input.review.object.metadata

# violation if pod has no ownerReferences.
violation[{"msg": msg}] {
    input.review.object.kind == "Pod"
    missing(metadata, "ownerReferences")
    not check_annotation
    msg := sprintf("The Pod <%v> does not have any ownerReferences. This can prevent autoscaler from scaling down a node where this is running. Read more about this and possible solutions at https://elastisys.io/welkin/user-guide/safeguards/enforce-no-pod-without-controller",[metadata.name])
}

# violation if ownerReferences is empty.
violation[{"msg": msg}] {
    input.review.object.kind == "Pod"
    metadata.ownerReferences == []
    not check_annotation
    msg := sprintf("The Pod <%v> does not have any ownerReferences. This can prevent autoscaler from scaling down a node where this is running. Read more about this and possible solutions at https://elastisys.io/welkin/user-guide/safeguards/enforce-no-pod-without-controller",[metadata.name])
}

# Field missing if it does not exist in the object
missing(obj, field) {
    not obj[field]
}

check_annotation {
    metadata.annotations[input.parameters.annotation] == "true"
}
