package test.k8sresourcerequests

import data.k8sresourcerequests

#
# Help functions
#
generate_pod(containers) = obj {
    obj := {
        "review": {
            "object": {
                "kind": "Pod",
                "spec": {
                    "containers": containers
                }
            }
        }
    }
}

generate_resource_controller(kind, containers) = obj {
    obj := {
        "review": {
            "object": {
                "kind": kind,
                "spec": {
                    "template": {
                        "spec": {
                            "containers": containers
                        }
                    }
                }
            }
        }
    }
}

generate_cronJob(containers) = obj {
    obj := {
        "review": {
            "object": {
                "kind": "CronJob",
                "spec": {
                    "jobTemplate": {
                        "spec": {
                            "template": {
                                "spec": {
                                    "containers": containers
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}


#
# Tests
#
test_pod_no_requests_deny {
    count(k8sresourcerequests.violation) == 1 with input as generate_pod(
        [
            {
                "name": "test",
                "resources": {}
            }
        ]
    )
}

test_pod_empty_requests_deny {
    count(k8sresourcerequests.violation) == 2 with input as generate_pod(
        [
            {
                "name": "test",
                "resources": {
                    "requests": {
                    }
                }
            }
        ]
    )
}

test_pod_no_cpu_deny {
    count(k8sresourcerequests.violation) == 1 with input as generate_pod(
        [
            {
                "name": "test",
                "resources": {
                    "requests": {
                        "memory": "100Mi"
                    }
                }
            }
        ]
    )
}

test_pod_no_memory_deny {
    count(k8sresourcerequests.violation) == 1 with input as generate_pod(
        [
            {
                "name": "test",
                "resources": {
                    "requests": {
                        "cpu": "100m"
                    }
                }
            }
        ]
    )
}

test_pod_good_requests_allow {
    count(k8sresourcerequests.violation) == 0 with input as generate_pod(
        [
            {
                "name": "test",
                "resources": {
                    "requests": {
                        "cpu": "100m",
                        "memory": "100Mi"
                    }
                }
            }
        ]
    )
}

kinds := [
    "Deployment",
    "StatefulSet",
    "DaemonSet",
    "ReplicaSet",
    "Job",
    "ReplicationController"
]

test_resource_controller_no_requests_deny {
    res = [test | test = count(k8sresourcerequests.violation) == 1 with input as generate_resource_controller(
        kinds[_],
        [
            {
                "name": "test",
                "resources": {}
            }
        ]
    )]
    all(res)
}

test_resource_controller_empty_requests_deny {
    res = [test | test = count(k8sresourcerequests.violation) == 2 with input as generate_resource_controller(
        kinds[_],
        [
            {
                "name": "test",
                "resources": {
                    "requests": {
                    }
                }
            }
        ]
    )]
    all(res)
}

test_resource_controller_no_cpu_deny {
    res = [test | test = count(k8sresourcerequests.violation) == 1 with input as generate_resource_controller(
        kinds[_],
        [
            {
                "name": "test",
                "resources": {
                    "requests": {
                        "memory": "100Mi"
                    }
                }
            }
        ]
    )]
    all(res)
}

test_resource_controller_no_memory_deny {
    res = [test | test = count(k8sresourcerequests.violation) == 1 with input as generate_resource_controller(
        kinds[_],
        [
            {
                "name": "test",
                "resources": {
                    "requests": {
                        "cpu": "100m"
                    }
                }
            }
        ]
    )]
    all(res)
}

test_resource_controller_good_requests_allow {
    res = [test | test = count(k8sresourcerequests.violation) == 0 with input as generate_resource_controller(
        kinds[_],
        [
            {
                "name": "test",
                "resources": {
                    "requests": {
                        "cpu": "100m",
                        "memory": "100Mi"
                    }
                }
            }
        ]
    )]
    all(res)
}

test_cronJob_no_requests_deny {
    count(k8sresourcerequests.violation) == 1 with input as generate_cronJob(
        [
            {
                "name": "test",
                "resources": {}
            }
        ]
    )
}

test_cronJob_empty_requests_deny {
    count(k8sresourcerequests.violation) == 2 with input as generate_cronJob(
        [
            {
                "name": "test",
                "resources": {
                    "requests": {
                    }
                }
            }
        ]
    )
}

test_cronJob_no_cpu_deny {
    count(k8sresourcerequests.violation) == 1 with input as generate_cronJob(
        [
            {
                "name": "test",
                "resources": {
                    "requests": {
                        "memory": "100Mi"
                    }
                }
            }
        ]
    )
}

test_cronJob_no_memory_deny {
    count(k8sresourcerequests.violation) == 1 with input as generate_cronJob(
        [
            {
                "name": "test",
                "resources": {
                    "requests": {
                        "cpu": "100m"
                    }
                }
            }
        ]
    )
}

test_cronJob_good_requests_allow {
    count(k8sresourcerequests.violation) == 0 with input as generate_cronJob(
        [
            {
                "name": "test",
                "resources": {
                    "requests": {
                        "cpu": "100m",
                        "memory": "100Mi"
                    }
                }
            }
        ]
    )
}
