package k8sminimumreplicas

        object_name = input.review.object.metadata.name
        object_kind = input.review.kind.kind

        violation[{"msg": msg}] {
            spec := input.review.object.spec
            not input_replica_limit(spec)
            msg := sprintf("The provided number of replicas is low for %v: %v. Elastisys Compliant Kubernetes recommends a minimum of 2 replicas.", [object_kind, object_name])
        }

        input_replica_limit(spec) {
            provided := spec.replicas
            min_replicas := input.parameters.min_replicas[_]
            value_superior_min_replicas(min_replicas, provided)
        }

        value_superior_min_replicas(min_replicas, value) {
            min_replicas > value
        }
