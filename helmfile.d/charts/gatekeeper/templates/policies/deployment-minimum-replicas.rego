package k8sminimumreplicas

import future.keywords.in

object_name = input.review.object.metadata.name
object_kind = input.review.kind.kind

violation[{"msg": msg}] {
    spec := input.review.object.spec
    metadata := input.review.object.metadata
    not input_replica_limit(spec)
    not check_annotation(metadata)
    msg := sprintf("The provided number of replicas is too low for %v: %v. Elastisys Welkin® recommends a minimum of 2 replicas. More Info: https://elastisys.io/welkin/user-guide/safeguards/enforce-minimum-replicas", [object_kind, object_name])
}

input_replica_limit(spec) {
    provided := spec.replicas
    min_replicas := input.parameters.min_replicas
    min_replicas <= provided
}

check_annotation(metadata) {
    provided := metadata.annotations
    value := input.parameters.annotation

    some key, _ in provided
    key == value
}
