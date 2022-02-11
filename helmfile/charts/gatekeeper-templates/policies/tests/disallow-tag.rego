package test.k8sdisallowedtags

import data.k8sdisallowedtags

#
# Help functions
#
generate_pod(tags, containers) = obj {
    obj := {
        "parameters": {
            "tags": tags
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

generate_pod_with_initContainer(tags, containers, initContainers) = obj {
    obj := {
        "parameters": {
            "tags": tags
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

generate_resource_controller(tags, kind, containers) = obj {
    obj := {
        "parameters": {
            "tags": tags
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

generate_resource_controller_with_initContainer(tags, kind, containers, initContainers) = obj {
    obj := {
        "parameters": {
            "tags": tags
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

generate_cronJob(tags, containers) = obj {
    obj := {
        "parameters": {
            "tags": tags
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

generate_cronJob_with_initContainer(tags, containers, initContainers) = obj {
    obj := {
        "parameters": {
            "tags": tags
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
test_pod_bad_tag_deny {
    count(k8sdisallowedtags.violation) == 1 with input as generate_pod(
        [
            "latest",
        ],
        [
            {
                "name": "test",
                "image": "nginx:latest"
            }
        ]
    )
}

test_pod_good_tag_allow {
    count(k8sdisallowedtags.violation) == 0 with input as generate_pod(
        [
            "latest"
        ],
        [
            {
                "name": "test",
                "image": "nginx:1.21.6"
            }
        ]
    )
}

test_pod_bad_tag_initContainer_deny {
    count(k8sdisallowedtags.violation) == 1 with input as generate_pod_with_initContainer(
        [
            "latest"
        ],
        [
            {
                "name": "container",
                "image": "harbor.example.com/test/nginx:1.21.6"
            }
        ],
        [
            {
                "name": "initContainer",
                "image": "nginx:latest"
            }
        ]
    )
}

test_pod_good_initContainer_allow {
    count(k8sdisallowedtags.violation) == 0 with input as generate_pod_with_initContainer(
        [
            "latest"
        ],
        [
            {
                "name": "container",
                "image": "harbor.example.com/test/nginx:1.21.6"
            }
        ],
        [
            {
                "name": "initContainer",
                "image": "other.secure-registry.com/test/nginx:1.21.6"
            }
        ]
    )
}

test_pod_multiple_containers_deny {
    count(k8sdisallowedtags.violation) == 2 with input as generate_pod(
        [
            "latest"
        ],
        [
            {
                "name": "allow1",
                "image": "harbor.example.com/test/nginx:1.21.6"
            },
            {
                "name": "allow2",
                "image": "other.secure-registry.com/ubuntu:1.21.6"
            },
            {
                "name": "deny1",
                "image": "harbor.bad.com/test/nginx:latest"
            },
            {
                "name": "deny2",
                "image": "nginx:latest"
            }
        ]
    )
}

test_pod_multiple_containers_and_initContainers_deny {
    count(k8sdisallowedtags.violation) == 3 with input as generate_pod_with_initContainer(
        [
            "latest"
        ],
        [
            {
                "name": "allow1",
                "image": "harbor.example.com/test/nginx:1.21.6"
            },
            {
                "name": "allow2",
                "image": "other.secure-registry.com/ubuntu:1.21.6"
            },
            {
                "name": "deny1",
                "image": "harbor.bad.com/test/nginx:latest"
            },
            {
                "name": "deny2",
                "image": "nginx:latest"
            }
        ],
        [
            {
                "name": "allow",
                "image": "harbor.example.com/test/ubuntu:18.04"
            },
            {
                "name": "deny",
                "image": "harbor.bad.com/test/ubuntu:latest"
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

test_resource_controller_bad_tag_deny {
    res = [test | test = count(k8sdisallowedtags.violation) == 1 with input as generate_resource_controller(
        [
            "latest"
        ],
        kinds[_],
        [
            {
                "name": "test",
                "image": "nginx:latest"
            }
        ]
    )]
    all(res)
}

test_resource_controller_good_tag_allow {
    res = [test | test = count(k8sdisallowedtags.violation) == 0 with input as generate_resource_controller(
        [
            "latest"
        ],
        kinds[_],
        [
            {
                "name": "test",
                "image": "harbor.example.com/test/nginx:1.21.6"
            }
        ]
    )]
    all(res)
}

test_resource_controller_bad_initContainer_deny {
    res = [test | test = count(k8sdisallowedtags.violation) == 1 with input as generate_resource_controller_with_initContainer(
        [
            "latest"
        ],
        kinds[_],
        [
            {
                "name": "container",
                "image": "harbor.example.com/test/nginx:1.21.6"
            }
        ],
        [
            {
                "name": "initContainer",
                "image": "nginx:latest"
            }
        ]
    )]
    all(res)
}

test_resource_controller_good_initContainer_allow {
    res = [test | test = count(k8sdisallowedtags.violation) == 0 with input as generate_resource_controller_with_initContainer(
        [
            "latest"
        ],
        kinds[_],
        [
            {
                "name": "container",
                "image": "harbor.example.com/test/nginx:1.21.6"
            }
        ],
        [
            {
                "name": "initContainer",
                "image": "other.secure-registry.com/test/nginx:1.21.6"
            }
        ]
    )]
    all(res)
}

test_resource_controller_multiple_containers_deny {
    res = [test | test = count(k8sdisallowedtags.violation) == 2 with input as generate_resource_controller(
        [
            "latest"
        ],
        kinds[_],
        [
            {
                "name": "allow1",
                "image": "harbor.example.com/test/nginx:1.21.6"
            },
            {
                "name": "allow2",
                "image": "other.secure-registry.com/ubuntu:18.04"
            },
            {
                "name": "deny1",
                "image": "harbor.bad.com/test/nginx:latest"
            },
            {
                "name": "deny2",
                "image": "nginx:latest"
            }
        ]
    )]
    all(res)
}

test_resource_controller_multiple_containers_and_initContainers_deny {
    res = [test | test = count(k8sdisallowedtags.violation) == 3 with input as generate_resource_controller_with_initContainer(
        [
            "latest"
        ],
        kinds[_],
        [
            {
                "name": "allow1",
                "image": "harbor.example.com/test/nginx:1.21.6"
            },
            {
                "name": "allow2",
                "image": "other.secure-registry.com/ubuntu:1.21.6"
            },
            {
                "name": "deny1",
                "image": "harbor.bad.com/test/nginx:latest"
            },
            {
                "name": "deny2",
                "image": "nginx:latest"
            }
        ],
        [
            {
                "name": "allow",
                "image": "harbor.example.com/test/ubuntu:1.21.6"
            },
            {
                "name": "deny",
                "image": "harbor.bad.com/test/ubuntu:latest"
            }
        ],
    )]
    all(res)
}

test_cronJob_bad_tag_deny {
    count(k8sdisallowedtags.violation) == 1 with input as generate_cronJob(
        [
            "latest"
        ],
        [
            {
                "name": "test",
                "image": "nginx:latest"
            }
        ]
    )
}

test_cronJob_good_tag_allow {
    count(k8sdisallowedtags.violation) == 0 with input as generate_cronJob(
        [
            "latest"
        ],
        [
            {
                "name": "test",
                "image": "harbor.example.com/test/nginx:1.21.6"
            }
        ]
    )
}

test_cronJob_bad_initContainer_deny {
    count(k8sdisallowedtags.violation) == 1 with input as generate_cronJob_with_initContainer(
        [
            "latest"
        ],
        [
            {
                "name": "container",
                "image": "harbor.example.com/test/nginx:1.21.6"
            }
        ],
        [
            {
                "name": "initContainer",
                "image": "nginx:latest"
            }
        ]
    )
}

test_cronJob_good_initContainer_allow {
    count(k8sdisallowedtags.violation) == 0 with input as generate_cronJob_with_initContainer(
        [
            "latest"
        ],
        [
            {
                "name": "container",
                "image": "harbor.example.com/test/nginx:1.21.6"
            }
        ],
        [
            {
                "name": "initContainer",
                "image": "other.secure-registry.com/test/nginx:1.21.6"
            }
        ]
    )
}

test_cronJob_multiple_containers_deny {
    count(k8sdisallowedtags.violation) == 2 with input as generate_cronJob(
        [
            "latest"
        ],
        [
            {
                "name": "allow1",
                "image": "harbor.example.com/test/nginx:1.21.6"
            },
            {
                "name": "allow2",
                "image": "other.secure-registry.com/ubuntu:18.04"
            },
            {
                "name": "deny1",
                "image": "harbor.bad.com/test/nginx:latest"
            },
            {
                "name": "deny2",
                "image": "nginx:latest"
            }
        ]
    )
}

test_cronJob_multiple_containers_and_initContainers_deny {
    count(k8sdisallowedtags.violation) == 3 with input as generate_cronJob_with_initContainer(
        [
            "latest"
        ],
        [
            {
                "name": "allow1",
                "image": "harbor.example.com/test/nginx:1.21.6"
            },
            {
                "name": "allow2",
                "image": "other.secure-registry.com/ubuntu:18.04"
            },
            {
                "name": "deny1",
                "image": "harbor.bad.com/test/nginx:latest"
            },
            {
                "name": "deny2",
                "image": "nginx:latest"
            }
        ],
        [
            {
                "name": "allow",
                "image": "harbor.example.com/test/ubuntu:18.04"
            },
            {
                "name": "deny",
                "image": "harbor.bad.com/test/ubuntu:latest"
            }
        ],
    )
}
