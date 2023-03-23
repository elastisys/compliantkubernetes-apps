package test.k8sallowedrepos

import data.k8sallowedrepos

#
# Help functions
#
generate_pod(repos, containers) = obj {
    obj := {
        "parameters": {
            "repos": repos
        },
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

generate_pod_with_initContainer(repos, containers, initContainers) = obj {
    obj := {
        "parameters": {
            "repos": repos
        },
        "review": {
            "object": {
                "kind": "Pod",
                "spec": {
                    "containers": containers,
                    "initContainers": initContainers
                }
            }
        }
    }
}

generate_resource_controller(repos, kind, containers) = obj {
    obj := {
        "parameters": {
            "repos": repos
        },
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

generate_resource_controller_with_initContainer(repos, kind, containers, initContainers) = obj {
    obj := {
        "parameters": {
            "repos": repos
        },
        "review": {
            "object": {
                "kind": kind,
                "spec": {
                    "template": {
                        "spec": {
                            "containers": containers,
                            "initContainers": initContainers
                        }
                    }
                }
            }
        }
    }
}

generate_cronJob(repos, containers) = obj {
    obj := {
        "parameters": {
            "repos": repos
        },
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

generate_cronJob_with_initContainer(repos, containers, initContainers) = obj {
    obj := {
        "parameters": {
            "repos": repos
        },
        "review": {
            "object": {
                "kind": "CronJob",
                "spec": {
                    "jobTemplate": {
                        "spec": {
                            "template": {
                                "spec": {
                                    "containers": containers,
                                    "initContainers": initContainers
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
test_pod_bad_image_deny {
    count(k8sallowedrepos.violation) == 1 with input as generate_pod(
        [
            "harbor.example.com",
            "other.secure-registry.com"
        ],
        [
            {
                "name": "test",
                "image": "nginx"
            }
        ]
    )
}

test_pod_good_image_allow {
    count(k8sallowedrepos.violation) == 0 with input as generate_pod(
        [
            "harbor.example.com",
            "other.secure-registry.com"
        ],
        [
            {
                "name": "test",
                "image": "harbor.example.com/test/nginx"
            }
        ]
    )
}

test_pod_bad_initContainer_deny {
    count(k8sallowedrepos.violation) == 1 with input as generate_pod_with_initContainer(
        [
            "harbor.example.com",
            "other.secure-registry.com"
        ],
        [
            {
                "name": "container",
                "image": "harbor.example.com/test/nginx"
            }
        ],
        [
            {
                "name": "initContainer",
                "image": "nginx"
            }
        ]
    )
}

test_pod_good_initContainer_allow {
    count(k8sallowedrepos.violation) == 0 with input as generate_pod_with_initContainer(
        [
            "harbor.example.com",
            "other.secure-registry.com"
        ],
        [
            {
                "name": "container",
                "image": "harbor.example.com/test/nginx"
            }
        ],
        [
            {
                "name": "initContainer",
                "image": "other.secure-registry.com/test/nginx"
            }
        ]
    )
}

test_pod_multiple_containers_deny {
    count(k8sallowedrepos.violation) == 2 with input as generate_pod(
        [
            "harbor.example.com",
            "other.secure-registry.com"
        ],
        [
            {
                "name": "allow1",
                "image": "harbor.example.com/test/nginx"
            },
            {
                "name": "allow2",
                "image": "other.secure-registry.com/ubuntu"
            },
            {
                "name": "deny1",
                "image": "harbor.bad.com/test/nginx"
            },
            {
                "name": "deny2",
                "image": "nginx"
            }
        ]
    )
}

test_pod_multiple_containers_and_initContainers_deny {
    count(k8sallowedrepos.violation) == 3 with input as generate_pod_with_initContainer(
        [
            "harbor.example.com",
            "other.secure-registry.com"
        ],
        [
            {
                "name": "allow1",
                "image": "harbor.example.com/test/nginx"
            },
            {
                "name": "allow2",
                "image": "other.secure-registry.com/ubuntu"
            },
            {
                "name": "deny1",
                "image": "harbor.bad.com/test/nginx"
            },
            {
                "name": "deny2",
                "image": "nginx"
            }
        ],
        [
            {
                "name": "allow",
                "image": "harbor.example.com/test/ubuntu"
            },
            {
                "name": "deny",
                "image": "harbor.bad.com/test/ubuntu"
            }
        ],
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

test_resource_controller_bad_image_deny {
    res = [test | test = count(k8sallowedrepos.violation) == 1 with input as generate_resource_controller(
        [
            "harbor.example.com",
            "other.secure-registry.com"
        ],
        kinds[_],
        [
            {
                "name": "test",
                "image": "nginx"
            }
        ]
    )]
    all(res)
}

test_resource_controller_good_image_allow {
    res = [test | test = count(k8sallowedrepos.violation) == 0 with input as generate_resource_controller(
        [
            "harbor.example.com",
            "other.secure-registry.com"
        ],
        kinds[_],
        [
            {
                "name": "test",
                "image": "harbor.example.com/test/nginx"
            }
        ]
    )]
    all(res)
}

test_resource_controller_bad_initContainer_deny {
    res = [test | test = count(k8sallowedrepos.violation) == 1 with input as generate_resource_controller_with_initContainer(
        [
            "harbor.example.com",
            "other.secure-registry.com"
        ],
        kinds[_],
        [
            {
                "name": "container",
                "image": "harbor.example.com/test/nginx"
            }
        ],
        [
            {
                "name": "initContainer",
                "image": "nginx"
            }
        ]
    )]
    all(res)
}

test_resource_controller_good_initContainer_allow {
    res = [test | test = count(k8sallowedrepos.violation) == 0 with input as generate_resource_controller_with_initContainer(
        [
            "harbor.example.com",
            "other.secure-registry.com"
        ],
        kinds[_],
        [
            {
                "name": "container",
                "image": "harbor.example.com/test/nginx"
            }
        ],
        [
            {
                "name": "initContainer",
                "image": "other.secure-registry.com/test/nginx"
            }
        ]
    )]
    all(res)
}

test_resource_controller_multiple_containers_deny {
    res = [test | test = count(k8sallowedrepos.violation) == 2 with input as generate_resource_controller(
        [
            "harbor.example.com",
            "other.secure-registry.com"
        ],
        kinds[_],
        [
            {
                "name": "allow1",
                "image": "harbor.example.com/test/nginx"
            },
            {
                "name": "allow2",
                "image": "other.secure-registry.com/ubuntu"
            },
            {
                "name": "deny1",
                "image": "harbor.bad.com/test/nginx"
            },
            {
                "name": "deny2",
                "image": "nginx"
            }
        ]
    )]
    all(res)
}

test_resource_controller_multiple_containers_and_initContainers_deny {
    res = [test | test = count(k8sallowedrepos.violation) == 3 with input as generate_resource_controller_with_initContainer(
        [
            "harbor.example.com",
            "other.secure-registry.com"
        ],
        kinds[_],
        [
            {
                "name": "allow1",
                "image": "harbor.example.com/test/nginx"
            },
            {
                "name": "allow2",
                "image": "other.secure-registry.com/ubuntu"
            },
            {
                "name": "deny1",
                "image": "harbor.bad.com/test/nginx"
            },
            {
                "name": "deny2",
                "image": "nginx"
            }
        ],
        [
            {
                "name": "allow",
                "image": "harbor.example.com/test/ubuntu"
            },
            {
                "name": "deny",
                "image": "harbor.bad.com/test/ubuntu"
            }
        ],
    )]
    all(res)
}

test_cronJob_bad_image_deny {
    count(k8sallowedrepos.violation) == 1 with input as generate_cronJob(
        [
            "harbor.example.com",
            "other.secure-registry.com"
        ],
        [
            {
                "name": "test",
                "image": "nginx"
            }
        ]
    )
}

test_cronJob_good_image_allow {
    count(k8sallowedrepos.violation) == 0 with input as generate_cronJob(
        [
            "harbor.example.com",
            "other.secure-registry.com"
        ],
        [
            {
                "name": "test",
                "image": "harbor.example.com/test/nginx"
            }
        ]
    )
}

test_cronJob_bad_initContainer_deny {
    count(k8sallowedrepos.violation) == 1 with input as generate_cronJob_with_initContainer(
        [
            "harbor.example.com",
            "other.secure-registry.com"
        ],
        [
            {
                "name": "container",
                "image": "harbor.example.com/test/nginx"
            }
        ],
        [
            {
                "name": "initContainer",
                "image": "nginx"
            }
        ]
    )
}

test_cronJob_good_initContainer_allow {
    count(k8sallowedrepos.violation) == 0 with input as generate_cronJob_with_initContainer(
        [
            "harbor.example.com",
            "other.secure-registry.com"
        ],
        [
            {
                "name": "container",
                "image": "harbor.example.com/test/nginx"
            }
        ],
        [
            {
                "name": "initContainer",
                "image": "other.secure-registry.com/test/nginx"
            }
        ]
    )
}

test_cronJob_multiple_containers_deny {
    count(k8sallowedrepos.violation) == 2 with input as generate_cronJob(
        [
            "harbor.example.com",
            "other.secure-registry.com"
        ],
        [
            {
                "name": "allow1",
                "image": "harbor.example.com/test/nginx"
            },
            {
                "name": "allow2",
                "image": "other.secure-registry.com/ubuntu"
            },
            {
                "name": "deny1",
                "image": "harbor.bad.com/test/nginx"
            },
            {
                "name": "deny2",
                "image": "nginx"
            }
        ]
    )
}

test_cronJob_multiple_containers_and_initContainers_deny {
    count(k8sallowedrepos.violation) == 3 with input as generate_cronJob_with_initContainer(
        [
            "harbor.example.com",
            "other.secure-registry.com"
        ],
        [
            {
                "name": "allow1",
                "image": "harbor.example.com/test/nginx"
            },
            {
                "name": "allow2",
                "image": "other.secure-registry.com/ubuntu"
            },
            {
                "name": "deny1",
                "image": "harbor.bad.com/test/nginx"
            },
            {
                "name": "deny2",
                "image": "nginx"
            }
        ],
        [
            {
                "name": "allow",
                "image": "harbor.example.com/test/ubuntu"
            },
            {
                "name": "deny",
                "image": "harbor.bad.com/test/ubuntu"
            }
        ],
    )
}
