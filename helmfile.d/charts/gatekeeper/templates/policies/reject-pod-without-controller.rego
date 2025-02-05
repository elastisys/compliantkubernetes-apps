package k8srejectpodwithoutcontroller

metadata := input.review.object.metadata

# violation if volume has no medium.
violation[{"msg": msg}] {
    input.review.object.kind == "Pod"
	missing(metadata, "ownerReferences")
    not check_annotation
    msg := sprintf("The Pod <%v> does not have any ownerReferences. This can prevent autoscaler from scaling down a node where this is running. Consider running the pod as part of a Deployment (or other controller) or add the annotation %v: \"true\" ",[metadata.name, input.parameters.annotation])
}

# violation if medium is not Memory.
violation[{"msg": msg}] {
    input.review.object.kind == "Pod"
	metadata.ownerReferences == []
    not check_annotation
    msg := sprintf("The Pod <%v> does not have any ownerReferences. This can prevent autoscaler from scaling down a node where this is running. Consider running the pod as part of a Deployment (or other controller) or add the annotation %v: \"true\" ",[metadata.name, input.parameters.annotation])
}

# Field missing if it does not exist in the object
missing(obj, field) {
    not obj[field]
}

check_annotation {
	metadata.annotations[input.parameters.annotation] == "true"
}
