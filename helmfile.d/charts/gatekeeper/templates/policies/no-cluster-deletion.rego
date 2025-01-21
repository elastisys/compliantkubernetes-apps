package k8snoclusterdeletion

violation[{"msg": msg}] {
    kinds := {
        "Cluster",
        "OpenStackCluster"
    }

    input.review.object.kind == kinds[_]
    input.review.operation == "DELETE"
    not (input.review.object.metadata.labels["ok-to-delete"] == "true")

    msg := sprintf("Cluster deletion is not allowed.\nTo bypass the constraint, run:\nkubectl label %v -n %v %v ok-to-delete=true",[input.review.object.kind, input.review.namespace, input.review.name])
}
