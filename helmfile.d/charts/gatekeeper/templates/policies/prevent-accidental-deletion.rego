package k8spreventaccidentaldeletion

import future.keywords.in

violation[{"msg": msg}] {

    input.review.operation == "DELETE"
    not correct_annotation
    correct_kind

    msg := sprintf(
        "%v deletion is not allowed.\nTo bypass the constraint, run:\nkubectl annotate %v -n %v %v %v=anything",
        [
            input.review.object.kind,
            input.review.object.kind,
            input.review.object.metadata.namespace,
            input.review.object.metadata.name,
            input.parameters.annotation
        ]
    )
}

correct_annotation {

    annotations := input.review.object.metadata.annotations
    value := input.parameters.annotation

    some key, _ in annotations
    key == value
}

correct_kind {

    kind := input.review.object.kind
    kinds := input.parameters.kinds

    kinds[_] == kind
}
