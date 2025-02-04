package test.k8srejectemptydir

import data.k8srejectemptydir

#
# Help functions
#

generate_resources(kind, annotation, annotations, volumes) = obj {
    kind == "Pod"
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
generate_resources(kind, annotation, annotations, volumes) = obj {
    allowed_kinds := [
        "Deployment",
        "StatefulSet",
        "DaemonSet",
        "ReplicaSet",
        "Job",
        "ReplicationController"
    ]
	kind == allowed_kinds[_]
	obj := {
		"parameters": {
			"annotation": annotation
		},
		"review": {
			"object": {
				"kind": kind,
				"spec": {
					"template": {
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
	}
}
generate_resources(kind, annotation, annotations, volumes) = obj {
	kind == "CronJob"
	obj := {
		"parameters": {
			"annotation": annotation
		},
		"review": {
			"object": {
				"kind": "CronJob",
				"spec": {
					"jobTemplate": {
						"spec": {
							"template": {
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
			}
		}
	}
}

kinds := [
	"Pod",
	"Deployment",
	"StatefulSet",
	"DaemonSet",
	"ReplicaSet",
	"Job",
	"ReplicationController",
	"CronJob"
]

#
# Tests
#

test_emptydir_memory {
    res = [test | test = count(k8srejectemptydir.violation) == 0 with input as generate_resources(
		kinds[_],
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
    )]
	all(res)
}

test_emptydir_no_annotations {

	res = [test | test = count(k8srejectemptydir.violation) == 1 with input as generate_resources(
		kinds[_],
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
	)]
	all(res)
}

test_emptydir_with_annotation {
    res = [test | test = count(k8srejectemptydir.violation) == 0 with input as generate_resources(
		kinds[_],
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
    )]
	all(res)
}

test_emptydir_with_wrong_annotation_key {
    res = [test | test = count(k8srejectemptydir.violation) == 1 with input as generate_resources(
		kinds[_],
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
    )]
	all(res)
}

test_emptydir_with_wrong_annotation_value {
    res = [test | test = count(k8srejectemptydir.violation) == 1 with input as generate_resources(
		kinds[_],
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
    )]
	all(res)
}
