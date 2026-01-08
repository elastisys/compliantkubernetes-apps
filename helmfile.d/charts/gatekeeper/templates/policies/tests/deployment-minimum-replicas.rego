package test.k8sminimumreplicas

import data.k8sminimumreplicas

#
# Helper functions
#
generate_deployment(name, replicas) = obj {
    obj := {
        "review": {
            "object": {
                "kind": "Deployment",
                "metadata": {
                    "name": name
                },
                "spec": {
                    "replicas": replicas
                }
            },
            "kind": {
                "kind": "Deployment"
            }
        },
        "parameters": {
            "min_replicas": 2,
            "annotation": "elastisys.io/ignore-minimum-replicas"
        }
    }
}

generate_deployment_with_annotation(name, replicas, annotations) = obj {
    obj := {
        "review": {
            "object": {
                "kind": "Deployment",
                "metadata": {
                    "name": name,
                    "annotations": annotations
                },
                "spec": {
                    "replicas": replicas
                }
            },
            "kind": {
                "kind": "Deployment"
            }
        },
        "parameters": {
            "min_replicas": 2,
            "annotation": "elastisys.io/ignore-minimum-replicas"
        }
    }
}

generate_statefulset(name, replicas) = obj {
    obj := {
        "review": {
            "object": {
                "kind": "StatefulSet",
                "metadata": {
                    "name": name
                },
                "spec": {
                    "replicas": replicas
                }
            },
            "kind": {
                "kind": "StatefulSet"
            }
        },
        "parameters": {
            "min_replicas": 2,
            "annotation": "elastisys.io/ignore-minimum-replicas"
        }
    }
}

#
# Tests
#

# Deployment with 1 replica should trigger violation
test_deployment_one_replica_deny {
    count(k8sminimumreplicas.violation) == 1 with input as generate_deployment("test-deploy", 1)
}

# Deployment with 2 replicas should be allowed
test_deployment_two_replicas_allow {
    count(k8sminimumreplicas.violation) == 0 with input as generate_deployment("test-deploy", 2)
}

# Deployment with 3 replicas should be allowed
test_deployment_three_replicas_allow {
    count(k8sminimumreplicas.violation) == 0 with input as generate_deployment("test-deploy", 3)
}

# StatefulSet with 1 replica should trigger violation
test_statefulset_one_replica_deny {
    count(k8sminimumreplicas.violation) == 1 with input as generate_statefulset("test-sts", 1)
}

# StatefulSet with 2 replicas should be allowed
test_statefulset_two_replicas_allow {
    count(k8sminimumreplicas.violation) == 0 with input as generate_statefulset("test-sts", 2)
}

# Deployment with 1 replica but ignore annotation should be allowed
test_deployment_one_replica_with_ignore_annotation_allow {
    count(k8sminimumreplicas.violation) == 0 with input as generate_deployment_with_annotation(
        "test-deploy",
        1,
        {"elastisys.io/ignore-minimum-replicas": "true"}
    )
}

# Deployment with 1 replica and different annotation should still trigger violation
test_deployment_one_replica_with_other_annotation_deny {
    count(k8sminimumreplicas.violation) == 1 with input as generate_deployment_with_annotation(
        "test-deploy",
        1,
        {"some-other-annotation": "value"}
    )
}
