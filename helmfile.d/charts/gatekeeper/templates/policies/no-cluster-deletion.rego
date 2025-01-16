package k8snoclusterdeletion

violation[{"msg": msg}] {
    kinds := [
        "Cluster",
        "Openstackcluster"
    ]

    input.review.object.kind == kinds[_]
    input.review.operation == "DELETE"

    msg := "Cluster deletion is not allowed."
}
