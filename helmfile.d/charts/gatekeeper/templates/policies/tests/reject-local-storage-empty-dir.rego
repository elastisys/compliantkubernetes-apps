package test.k8srejectlocalstorageemptydir

import data.k8srejectlocalstorageemptydir

#
# Help functions
#

generate_resources(kind, volumeAnnotation, podAnnotation, annotations, volumes) = obj {
    kind == "Pod"
    obj := {
        "parameters": {
            "volumeAnnotation": volumeAnnotation,
            "podAnnotation": podAnnotation
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
generate_resources(kind, volumeAnnotation, podAnnotation, annotations, volumes) = obj {
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
            "volumeAnnotation": volumeAnnotation,
            "podAnnotation": podAnnotation
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
generate_resources(kind, volumeAnnotation, podAnnotation, annotations, volumes) = obj {
    kind == "CronJob"
    obj := {
        "parameters": {
            "volumeAnnotation": volumeAnnotation,
            "podAnnotation": podAnnotation
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

test_no_volume {
    res = [test | test = count(k8srejectlocalstorageemptydir.violation) == 0 with input as generate_resources(
        kinds[_],
        "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes",
        "cluster-autoscaler.kubernetes.io/safe-to-evict",
        {},
        []
    )]
    all(res)
}

test_emptydir_memory {
    res = [test | test = count(k8srejectlocalstorageemptydir.violation) == 0 with input as generate_resources(
        kinds[_],
        "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes",
        "cluster-autoscaler.kubernetes.io/safe-to-evict",
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

test_emptydir_wrong_medium {
    res = [test | test = count(k8srejectlocalstorageemptydir.violation) == 1 with input as generate_resources(
        kinds[_],
        "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes",
        "cluster-autoscaler.kubernetes.io/safe-to-evict",
        {},
        [
            {
                "name": "emptydir-volume",
                "emptyDir": {
                    "sizeLimit": "500Mi",
                    "medium": "Not-memory"
                }
            }
        ]
    )]
    all(res)
}

test_emptydir_no_annotations {

    res = [test | test = count(k8srejectlocalstorageemptydir.violation) == 1 with input as generate_resources(
        kinds[_],
        "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes",
        "cluster-autoscaler.kubernetes.io/safe-to-evict",
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

# Tests for volume annotation
test_emptydir_with_volume_annotation {
    res = [test | test = count(k8srejectlocalstorageemptydir.violation) == 0 with input as generate_resources(
        kinds[_],
        "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes",
        "cluster-autoscaler.kubernetes.io/safe-to-evict",
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

test_emptydir_with_wrong_volume_annotation_key {
    res = [test | test = count(k8srejectlocalstorageemptydir.violation) == 1 with input as generate_resources(
        kinds[_],
        "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes",
        "cluster-autoscaler.kubernetes.io/safe-to-evict",
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

test_emptydir_with_wrong_volume_annotation_value {
    res = [test | test = count(k8srejectlocalstorageemptydir.violation) == 1 with input as generate_resources(
        kinds[_],
        "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes",
        "cluster-autoscaler.kubernetes.io/safe-to-evict",
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

test_emptydir_with_two_allowed_volumes {
    res = [test | test = count(k8srejectlocalstorageemptydir.violation) == 0 with input as generate_resources(
        kinds[_],
        "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes",
        "cluster-autoscaler.kubernetes.io/safe-to-evict",
        {
            "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes": "allowed_volume1,allowed_volume2"
        },
        [
            {
                "name": "allowed_volume1",
                "emptyDir": {
                    "sizeLimit": "500Mi"
                }
            },
            {
                "name": "allowed_volume2",
                "emptyDir": {
                    "sizeLimit": "500Mi"
                }
            }
        ]
    )]
    all(res)
}

test_emptydir_with_one_allowed_one_disallowed_volumes {
    res = [test | test = count(k8srejectlocalstorageemptydir.violation) == 1 with input as generate_resources(
        kinds[_],
        "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes",
        "cluster-autoscaler.kubernetes.io/safe-to-evict",
        {
            "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes": "allowed_volume"
        },
        [
            {
                "name": "allowed_volume",
                "emptyDir": {
                    "sizeLimit": "500Mi"
                }
            },
            {
                "name": "disallowed_volume",
                "emptyDir": {
                    "sizeLimit": "500Mi"
                }
            }
        ]
    )]
    all(res)
}

test_emptydir_with_two_disallowed_volumes {
    res = [test | test = count(k8srejectlocalstorageemptydir.violation) == 2 with input as generate_resources(
        kinds[_],
        "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes",
        "cluster-autoscaler.kubernetes.io/safe-to-evict",
        {
            "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes": ""
        },
        [
            {
                "name": "disallowed_volume1",
                "emptyDir": {
                    "sizeLimit": "500Mi"
                }
            },
            {
                "name": "disallowed_volume2",
                "emptyDir": {
                    "sizeLimit": "500Mi"
                }
            }
        ]
    )]
    all(res)
}

#Tests for pod annotation
test_emptydir_with_pod_annotation {
    res = [test | test = count(k8srejectlocalstorageemptydir.violation) == 0 with input as generate_resources(
        kinds[_],
        "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes",
        "cluster-autoscaler.kubernetes.io/safe-to-evict",
        {
            "cluster-autoscaler.kubernetes.io/safe-to-evict": "true"
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

test_emptydir_with_wrong_pod_annotation_key {
    res = [test | test = count(k8srejectlocalstorageemptydir.violation) == 1 with input as generate_resources(
        kinds[_],
        "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes",
        "cluster-autoscaler.kubernetes.io/safe-to-evict",
        {
            "bad-annotation": "true"
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

test_emptydir_with_wrong_pod_annotation_value {
    res = [test | test = count(k8srejectlocalstorageemptydir.violation) == 1 with input as generate_resources(
        kinds[_],
        "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes",
        "cluster-autoscaler.kubernetes.io/safe-to-evict",
        {
            "cluster-autoscaler.kubernetes.io/safe-to-evict": "another-value"
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

#Test for both annotations
test_emptydir_with_both_annotations {
    res = [test | test = count(k8srejectlocalstorageemptydir.violation) == 0 with input as generate_resources(
        kinds[_],
        "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes",
        "cluster-autoscaler.kubernetes.io/safe-to-evict",
        {
            "cluster-autoscaler.kubernetes.io/safe-to-evict-local-volumes": "emptydir-volume",
            "cluster-autoscaler.kubernetes.io/safe-to-evict": "true"
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
