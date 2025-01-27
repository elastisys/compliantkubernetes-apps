package test.k8srejectemptydir

import data.k8srejectemptydir

#
# Help functions
#
generate_pod(annotation, annotations, volumes) = obj {
    obj := {
        "parameters": {
            "annotation": annotation
        },
        "review": {
            "object": {
                "kind": "Pod",
				"metadata": {
					"annotations": annotations
				},
                "spec": {
                    "volumes": volumes
                }
            }
        }
    }
}

#
# Tests
#

test_pod_emptydir_memory {
    count(k8srejectemptydir.violation) == 0 with input as generate_pod(
        "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes",
        {},
		[
			{
				"name": "emptydir-volume",
				"emptyDir": {
					"sizeLimit": "500Mi",
					"medium": "Memory"
				}
			}
		]
    )
}

test_pod_emptydir_no_annotations {
    count(k8srejectemptydir.violation) == 1 with input as generate_pod(
        "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes",
        {},
		[
			{
				"name": "emptydir-volume",
				"emptyDir": {
					"sizeLimit": "500Mi"
				}
			}
		]
    )
}

test_pod_emptydir_with_annotation {
    count(k8srejectemptydir.violation) == 0 with input as generate_pod(
        "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes",
        {
            "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes": "emptydir-volume"
		},
		[
			{
				"name": "emptydir-volume",
				"emptyDir": {
					"sizeLimit": "500Mi"
				}
			}
		]
    )
}

test_pod_emptydir_with_wrong_annotation_key {
    count(k8srejectemptydir.violation) == 1 with input as generate_pod(
        "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes",
        {
            "bad-annotation": "emptydir-volume"
		},
		[
			{
				"name": "emptydir-volume",
				"emptyDir": {
					"sizeLimit": "500Mi"
				}
			}
		]
    )
}

test_pod_emptydir_with_wrong_annotation_value {
    count(k8srejectemptydir.violation) == 1 with input as generate_pod(
        "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes",
        {
            "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes": "another-volume"
		},
		[
			{
				"name": "emptydir-volume",
				"emptyDir": {
					"sizeLimit": "500Mi"
				}
			}
		]
    )
}
