package test.k8srejectpodwithoutcontroller

import data.k8srejectpodwithoutcontroller

#
# Help functions
#

generate_pod(annotation, metadata) = obj {
    obj := {
        "parameters": {
            "annotation": annotation
        },
        "review": {
            "object": {
                "kind": "Pod",
                "metadata": metadata
            }
        }
    }
}

#
# Tests
#

test_with_owner_reference {
    count(k8srejectpodwithoutcontroller.violation) == 0 with input as generate_pod(
        "cluster-autoscaler.kubernetes.io/safe-to-evict",
        {
            "name": "pod-name",
            "ownerReferences": [
                {
                    "apiVersion": "apps/v1",
                    "blockOwnerDeletion": "true",
                    "controller": "true",
                    "kind": "ReplicaSet",
                    "name": "replicaset-name",
                    "uid": "uid"
                }
            ]
        }
    )
}

test_without_owner_reference {
    count(k8srejectpodwithoutcontroller.violation) == 1 with input as generate_pod(
        "cluster-autoscaler.kubernetes.io/safe-to-evict",
        {
            "name": "pod-name"
        }
    )
}

test_with_empty_owner_reference {
    count(k8srejectpodwithoutcontroller.violation) == 1 with input as generate_pod(
        "cluster-autoscaler.kubernetes.io/safe-to-evict",
        {
            "name": "pod-name",
            "ownerReferences": []
        }
    )
}

test_with_annotation {
    count(k8srejectpodwithoutcontroller.violation) == 0 with input as generate_pod(
        "cluster-autoscaler.kubernetes.io/safe-to-evict",
        {
            "name": "pod-name",
            "annotations": {
                "cluster-autoscaler.kubernetes.io/safe-to-evict": "true"
            }
        }
    )
}

test_with_wrong_annotation_key {
    count(k8srejectpodwithoutcontroller.violation) == 1 with input as generate_pod(
        "cluster-autoscaler.kubernetes.io/safe-to-evict",
        {
            "name": "pod-name",
            "annotations": {
                "wrong-annotation": "true"
            }
        }
    )
}

test_with_wrong_annotation_value {
    count(k8srejectpodwithoutcontroller.violation) == 1 with input as generate_pod(
        "cluster-autoscaler.kubernetes.io/safe-to-evict",
        {
            "name": "pod-name",
            "annotations": {
                "cluster-autoscaler.kubernetes.io/safe-to-evict": "wrong"
            }
        }
    )
}
