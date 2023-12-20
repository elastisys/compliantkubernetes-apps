package test.k8sdisallowlocalhostseccomp

import data.k8sdisallowlocalhostseccomp

#
# Help functions
#
generate_pod_seccomp(type) = obj {
    obj := {
        "review": {
            "object": {
                "metadata": {
                    "name": "test-pod"
                },
                "kind": "Pod",
                "spec": {
                    "securityContext": {
                        "seccompProfile": {
                            "type": type
                        }
                    }
                }
            }
        }
    }
}

generate_resource_controller_seccomp(kind, type) = obj {
    obj := {
        "review": {
            "object": {
                "metadata": {
                    "name": "test-object"
                },
                "kind": kind,
                "spec": {
                    "template": {
                        "spec": {
                            "securityContext": {
                                "seccompProfile": {
                                    "type": type
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

generate_cronjob_seccomp(type) = obj {
    obj := {
        "review": {
            "object": {
                "metadata": {
                    "name": "test-object"
                },
                "kind": "CronJob",
                "spec": {
                    "jobTemplate": {
                        "spec": {
                            "template": {
                                "spec": {
                                    "securityContext": {
                                        "seccompProfile": {
                                            "type": type
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

generate_pod_container_seccomp(containers) = obj {
    obj := {
        "review": {
            "object": {
                "metadata": {
                    "name": "test-pod"
                },
                "kind": "Pod",
                "spec": {
                    "containers": containers
                }
            }
        }
    }
}

generate_rc_container_seccomp(kind, containers) = obj {
    obj := {
        "review": {
            "object": {
                "metadata": {
                    "name": "test-object"
                },
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

generate_cronjob_container_seccomp(containers) = obj {
    obj := {
        "review": {
            "object": {
                "metadata": {
                    "name": "test-cronjob"
                },
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

generate_pod_initcontainer_seccomp(containers) = obj {
    obj := {
        "review": {
            "object": {
                "metadata": {
                    "name": "test-pod"
                },
                "kind": "Pod",
                "spec": {
                    "initContainers": containers
                }
            }
        }
    }
}

generate_rc_initcontainer_seccomp(kind, containers) = obj {
    obj := {
        "review": {
            "object": {
                "metadata": {
                    "name": "test-object"
                },
                "kind": kind,
                "spec": {
                    "template": {
                        "spec": {
                            "initContainers": containers
                        }
                    }
                }
            }
        }
    }
}

generate_cronjob_initcontainer_seccomp(containers) = obj {
    obj := {
        "review": {
            "object": {
                "metadata": {
                    "name": "test-cronjob"
                },
                "kind": "CronJob",
                "spec": {
                    "jobTemplate": {
                        "spec": {
                            "template": {
                                "spec": {
                                    "initContainers": containers
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

generate_pod_ephemeralcontainer_seccomp(containers) = obj {
    obj := {
        "review": {
            "object": {
                "metadata": {
                    "name": "test-pod"
                },
                "kind": "Pod",
                "spec": {
                    "ephemeralContainers": containers
                }
            }
        }
    }
}

generate_rc_ephemeralcontainer_seccomp(kind, containers) = obj {
    obj := {
        "review": {
            "object": {
                "metadata": {
                    "name": "test-object"
                },
                "kind": kind,
                "spec": {
                    "template": {
                        "spec": {
                            "ephemeralContainers": containers
                        }
                    }
                }
            }
        }
    }
}

generate_cronjob_ephemeralcontainer_seccomp(containers) = obj {
    obj := {
        "review": {
            "object": {
                "metadata": {
                    "name": "test-cronjob"
                },
                "kind": "CronJob",
                "spec": {
                    "jobTemplate": {
                        "spec": {
                            "template": {
                                "spec": {
                                    "ephemeralContainers": containers
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
test_pod_bad_seccomp_type_deny {
    count(k8sdisallowlocalhostseccomp.violation) == 1 with input as generate_pod_seccomp("Localhost")
}

test_pod_good_seccomp_type_allow {
    count(k8sdisallowlocalhostseccomp.violation) == 0 with input as generate_pod_seccomp("RuntimeDefault")
}

test_rc_bad_seccomp_type_deny {
    count(k8sdisallowlocalhostseccomp.violation) == 1 with input as generate_resource_controller_seccomp(kinds[_], "Localhost")
}

test_rc_good_seccomp_type_allow {
    count(k8sdisallowlocalhostseccomp.violation) == 0 with input as generate_resource_controller_seccomp(kinds[_], "RuntimeDefault")
}

test_cronjob_bad_seccomp_type_deny {
    count(k8sdisallowlocalhostseccomp.violation) == 1 with input as generate_cronjob_seccomp("Localhost")
}

test_cronjob_good_seccomp_type_allow {
    count(k8sdisallowlocalhostseccomp.violation) == 0 with input as generate_cronjob_seccomp("RuntimeDefault")
}


test_pod_container_bad_seccomp_type_deny {
    count(k8sdisallowlocalhostseccomp.violation) == 1 with input as generate_pod_container_seccomp(
        [
            {
                "name": "test-container",
                "securityContext": {
                    "seccompProfile": {
                        "type": "Localhost"
                    }
                }
            }
        ]
    )
}

test_pod_container_good_seccomp_type_allow {
    count(k8sdisallowlocalhostseccomp.violation) == 0 with input as generate_pod_container_seccomp(
        [
            {
                "name": "test-container",
                "securityContext": {
                    "seccompProfile": {
                        "type": "RuntimeDefault"
                    }
                }
            }
        ]
    )
}

test_rc_container_bad_seccomp_type_deny {
    count(k8sdisallowlocalhostseccomp.violation) == 1 with input as generate_rc_container_seccomp(
        kinds[_],
        [
            {
                "name": "test-container",
                "securityContext": {
                    "seccompProfile": {
                        "type": "Localhost"
                    }
                }
            }
        ]
    )
}

test_rc_container_good_seccomp_type_allow {
    count(k8sdisallowlocalhostseccomp.violation) == 0 with input as generate_rc_container_seccomp(
        kinds[_],
        [
            {
                "name": "test-container",
                "securityContext": {
                    "seccompProfile": {
                        "type": "RuntimeDefault"
                    }
                }
            }
        ]
    )
}

test_cronjob_container_bad_seccomp_type_deny {
    count(k8sdisallowlocalhostseccomp.violation) == 1 with input as generate_cronjob_container_seccomp(
        [
            {
                "name": "test-container",
                "securityContext": {
                    "seccompProfile": {
                        "type": "Localhost"
                    }
                }
            }
        ]
    )
}

test_cronjob_container_good_seccomp_type_allow {
    count(k8sdisallowlocalhostseccomp.violation) == 0 with input as generate_cronjob_container_seccomp(
        [
            {
                "name": "test-container",
                "securityContext": {
                    "seccompProfile": {
                        "type": "RuntimeDefault"
                    }
                }
            }
        ]
    )
}

test_pod_initcontainer_bad_seccomp_type_deny {
    count(k8sdisallowlocalhostseccomp.violation) == 1 with input as generate_pod_initcontainer_seccomp(
        [
            {
                "name": "test-container",
                "securityContext": {
                    "seccompProfile": {
                        "type": "Localhost"
                    }
                }
            }
        ]
    )
}

test_pod_initcontainer_good_seccomp_type_allow {
    count(k8sdisallowlocalhostseccomp.violation) == 0 with input as generate_pod_initcontainer_seccomp(
        [
            {
                "name": "test-container",
                "securityContext": {
                    "seccompProfile": {
                        "type": "RuntimeDefault"
                    }
                }
            }
        ]
    )
}

test_rc_initcontainer_bad_seccomp_type_deny {
    count(k8sdisallowlocalhostseccomp.violation) == 1 with input as generate_rc_initcontainer_seccomp(
        kinds[_],
        [
            {
                "name": "test-container",
                "securityContext": {
                    "seccompProfile": {
                        "type": "Localhost"
                    }
                }
            }
        ]
    )
}

test_rc_initcontainer_good_seccomp_type_allow {
    count(k8sdisallowlocalhostseccomp.violation) == 0 with input as generate_rc_initcontainer_seccomp(
        kinds[_],
        [
            {
                "name": "test-container",
                "securityContext": {
                    "seccompProfile": {
                        "type": "RuntimeDefault"
                    }
                }
            }
        ]
    )
}

test_cronjob_initcontainer_bad_seccomp_type_deny {
    count(k8sdisallowlocalhostseccomp.violation) == 1 with input as generate_cronjob_initcontainer_seccomp(
        [
            {
                "name": "test-container",
                "securityContext": {
                    "seccompProfile": {
                        "type": "Localhost"
                    }
                }
            }
        ]
    )
}

test_cronjob_initcontainer_good_seccomp_type_allow {
    count(k8sdisallowlocalhostseccomp.violation) == 0 with input as generate_cronjob_initcontainer_seccomp(
        [
            {
                "name": "test-container",
                "securityContext": {
                    "seccompProfile": {
                        "type": "RuntimeDefault"
                    }
                }
            }
        ]
    )
}

test_pod_ephemeralcontainer_bad_seccomp_type_deny {
    count(k8sdisallowlocalhostseccomp.violation) == 1 with input as generate_pod_ephemeralcontainer_seccomp(
        [
            {
                "name": "test-container",
                "securityContext": {
                    "seccompProfile": {
                        "type": "Localhost"
                    }
                }
            }
        ]
    )
}

test_pod_ephemeralcontainer_good_seccomp_type_allow {
    count(k8sdisallowlocalhostseccomp.violation) == 0 with input as generate_pod_ephemeralcontainer_seccomp(
        [
            {
                "name": "test-container",
                "securityContext": {
                    "seccompProfile": {
                        "type": "RuntimeDefault"
                    }
                }
            }
        ]
    )
}

test_rc_ephemeralcontainer_bad_seccomp_type_deny {
    count(k8sdisallowlocalhostseccomp.violation) == 1 with input as generate_rc_ephemeralcontainer_seccomp(
        kinds[_],
        [
            {
                "name": "test-container",
                "securityContext": {
                    "seccompProfile": {
                        "type": "Localhost"
                    }
                }
            }
        ]
    )
}

test_rc_ephemeralcontainer_good_seccomp_type_allow {
    count(k8sdisallowlocalhostseccomp.violation) == 0 with input as generate_rc_ephemeralcontainer_seccomp(
        kinds[_],
        [
            {
                "name": "test-container",
                "securityContext": {
                    "seccompProfile": {
                        "type": "RuntimeDefault"
                    }
                }
            }
        ]
    )
}

test_cronjob_ephemeralcontainer_bad_seccomp_type_deny {
    count(k8sdisallowlocalhostseccomp.violation) == 1 with input as generate_cronjob_ephemeralcontainer_seccomp(
        [
            {
                "name": "test-container",
                "securityContext": {
                    "seccompProfile": {
                        "type": "Localhost"
                    }
                }
            }
        ]
    )
}

test_cronjob_ephemeralcontainer_good_seccomp_type_allow {
    count(k8sdisallowlocalhostseccomp.violation) == 0 with input as generate_cronjob_ephemeralcontainer_seccomp(
        [
            {
                "name": "test-container",
                "securityContext": {
                    "seccompProfile": {
                        "type": "RuntimeDefault"
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
