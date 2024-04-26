package test.k8sRequireNetworkPolicy

import data.k8sRequireNetworkPolicy

#
# Help functions
#
generate_pod(namespace, labels) = obj {
    obj := {
        "review": {
            "object": {
                "kind": "Pod",
                "metadata": {
                    "namespace": namespace,
                    "labels": labels
                }
            }
        }
    }
}

generate_pod_being_deleted(namespace, labels) = obj {
    obj := {
        "review": {
            "operation": "UPDATE",
            "object": {
                "kind": "Pod",
                "metadata": {
                    "namespace": namespace,
                    "labels": labels,
                    "deletionTimestamp": "2020-03-01T12:34:56Z"
                }
            },
            "oldObject": {
                "kind": "Pod",
                "metadata": {
                    "namespace": namespace,
                    "labels": labels,
                    "deletionTimestamp": "2020-03-01T12:34:56Z",
                    "finalizers" : [
                        "kubernetes"
                    ]
                }
            }
        }
    }
}

generate_resource_controller(kind, namespace, labels) = obj {
    obj := {
        "review": {
            "object": {
                "kind": kind,
                "metadata": {
                    "namespace": namespace
                },
                "spec": {
                    "template": {
                        "metadata": {
                            "labels": labels
                        }
                    }
                }
            }
        }
    }
}

generate_cronJob(namespace, labels) = obj {
    obj := {
        "review": {
            "object": {
                "kind": "CronJob",
                "metadata": {
                    "namespace": namespace
                },
                "spec": {
                    "jobTemplate": {
                        "spec": {
                            "template": {
                                "metadata": {
                                    "labels": labels
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

generate_network_policy(matchLabels, matchExpressions) = obj {
    obj := {
        "spec": {
            "podSelector": {
                "matchLabels": matchLabels,
                "matchExpressions": matchExpressions
            }
        }
    }
}

#
# Tests
#
test_pod_matchLabels_deny_key {
    count(k8sRequireNetworkPolicy.violation) == 1 with input as generate_pod(
        "default",
        {
            "wrongKey": "value"
        }
    ) with data.inventory as {"namespace": {"default": {"networking.k8s.io/v1": {"NetworkPolicy": [generate_network_policy(
        {
            "key": "value"
        },
        []
    )]}}}}
}

test_pod_matchLabels_deny_value {
    count(k8sRequireNetworkPolicy.violation) == 1 with input as generate_pod(
        "default",
        {
            "key": "wrongValue"
        }
    ) with data.inventory as {"namespace": {"default": {"networking.k8s.io/v1": {"NetworkPolicy": [generate_network_policy(
        {
            "key": "value"
        },
        []
    )]}}}}
}

test_pod_matchLabels_allow {
    count(k8sRequireNetworkPolicy.violation) == 0 with input as generate_pod(
        "default",
        {
            "key": "value"
        }
    ) with data.inventory as {"namespace": {"default": {"networking.k8s.io/v1": {"NetworkPolicy": [generate_network_policy(
        {
            "key": "value"
        },
        []
    )]}}}}
}

test_pod_matchExpressions_exists_deny {
    count(k8sRequireNetworkPolicy.violation) == 1 with input as generate_pod(
        "default",
        {
            "wrongKey": "value"
        }
    ) with data.inventory as {"namespace": {"default": {"networking.k8s.io/v1": {"NetworkPolicy": [generate_network_policy(
        {},
        [
            {
                "key": "key",
                "operator": "Exists"
            }
        ]
    )]}}}}
}

test_pod_matchExpressions_exists_allow {
    count(k8sRequireNetworkPolicy.violation) == 0 with input as generate_pod(
        "default",
        {
            "key": "value"
        }
    ) with data.inventory as {"namespace": {"default": {"networking.k8s.io/v1": {"NetworkPolicy": [generate_network_policy(
        {},
        [
            {
                "key": "key",
                "operator": "Exists"
            }
        ]
    )]}}}}
}

test_pod_matchExpressions_doesNotExists_deny {
    count(k8sRequireNetworkPolicy.violation) == 1 with input as generate_pod(
        "default",
        {
            "key": "value"
        }
    ) with data.inventory as {"namespace": {"default": {"networking.k8s.io/v1": {"NetworkPolicy": [generate_network_policy(
        {},
        [
            {
                "key": "key",
                "operator": "DoesNotExist"
            }
        ]
    )]}}}}
}

test_pod_matchExpressions_doesNotExists_allow {
    count(k8sRequireNetworkPolicy.violation) == 0 with input as generate_pod(
        "default",
        {
            "OtherKey": "value"
        }
    ) with data.inventory as {"namespace": {"default": {"networking.k8s.io/v1": {"NetworkPolicy": [generate_network_policy(
        {},
        [
            {
                "key": "key",
                "operator": "DoesNotExist"
            }
        ]
    )]}}}}
}

test_pod_matchExpressions_in_deny_key {
    count(k8sRequireNetworkPolicy.violation) == 1 with input as generate_pod(
        "default",
        {
            "wrongKey": "value"
        }
    ) with data.inventory as {"namespace": {"default": {"networking.k8s.io/v1": {"NetworkPolicy": [generate_network_policy(
        {},
        [
            {
                "key": "key",
                "operator": "In",
                "values": ["value"]
            }
        ]
    )]}}}}
}

test_pod_matchExpressions_in_deny_value {
    count(k8sRequireNetworkPolicy.violation) == 1 with input as generate_pod(
        "default",
        {
            "key": "wrongValue"
        }
    ) with data.inventory as {"namespace": {"default": {"networking.k8s.io/v1": {"NetworkPolicy": [generate_network_policy(
        {},
        [
            {
                "key": "key",
                "operator": "In",
                "values": ["value"]
            }
        ]
    )]}}}}
}

test_pod_matchExpressions_in_allow {
    count(k8sRequireNetworkPolicy.violation) == 0 with input as generate_pod(
        "default",
        {
            "key": "value"
        }
    ) with data.inventory as {"namespace": {"default": {"networking.k8s.io/v1": {"NetworkPolicy": [generate_network_policy(
        {},
        [
            {
                "key": "key",
                "operator": "In",
                "values": ["value"]
            }
        ]
    )]}}}}
}

test_pod_matchExpressions_notIn_deny {
    count(k8sRequireNetworkPolicy.violation) == 1 with input as generate_pod(
        "default",
        {
            "key": "value"
        }
    ) with data.inventory as {"namespace": {"default": {"networking.k8s.io/v1": {"NetworkPolicy": [generate_network_policy(
        {},
        [
            {
                "key": "key",
                "operator": "NotIn",
                "values": ["value"]
            }
        ]
    )]}}}}
}

test_pod_matchExpressions_notIn_allow_key {
    count(k8sRequireNetworkPolicy.violation) == 0 with input as generate_pod(
        "default",
        {
            "goodKey": "value"
        }
    ) with data.inventory as {"namespace": {"default": {"networking.k8s.io/v1": {"NetworkPolicy": [generate_network_policy(
        {},
        [
            {
                "key": "key",
                "operator": "NotIn",
                "values": ["value"]
            }
        ]
    )]}}}}
}

test_pod_matchExpressions_notIn_allow_value {
    count(k8sRequireNetworkPolicy.violation) == 0 with input as generate_pod(
        "default",
        {
            "key": "goodValue"
        }
    ) with data.inventory as {"namespace": {"default": {"networking.k8s.io/v1": {"NetworkPolicy": [generate_network_policy(
        {},
        [
            {
                "key": "key",
                "operator": "NotIn",
                "values": ["value"]
            }
        ]
    )]}}}}
}

test_pod_wrong_namespace_deny {
    count(k8sRequireNetworkPolicy.violation) == 1 with input as generate_pod(
        "wrongNamespace",
        {
            "key": "value"
        }
    ) with data.inventory as {"namespace": {"default": {"networking.k8s.io/v1": {"NetworkPolicy": [generate_network_policy(
        {
            "key": "value"
        },
        []
    )]}}}}
}

test_pod_mixed_selectors_deny {
    count(k8sRequireNetworkPolicy.violation) == 1 with input as generate_pod(
        "default",
        {
            "key": "value",
            "notExistKey": "value",
            "notInKey": "badValue1"
        }
    ) with data.inventory as {"namespace": {"default": {"networking.k8s.io/v1": {"NetworkPolicy": [generate_network_policy(
        {
            "key": "value",
            "matchKey": "matchValue"
        },
        [
            {
                "key": "existsKey",
                "operator": "Exists"
            },
            {
                "key": "notExistKey",
                "operator": "DoesNotExist"
            },
            {
                "key": "inKey",
                "operator": "In",
                "values": ["goodValue1", "goodValue2"]
            },
            {
                "key": "notInKey",
                "operator": "NotIn",
                "values": ["badValue1, badValue2"]
            }
        ]
    )]}}}}
}

test_pod_mixed_selectors_allow {
    count(k8sRequireNetworkPolicy.violation) == 0 with input as generate_pod(
        "default",
        {
            "key": "value",
            "matchKey": "matchValue",
            "existsKey": "value",
            "inKey": "goodValue1"
        }
    ) with data.inventory as {"namespace": {"default": {"networking.k8s.io/v1": {"NetworkPolicy": [generate_network_policy(
        {
            "key": "value",
            "matchKey": "matchValue"
        },
        [
            {
                "key": "existsKey",
                "operator": "Exists"
            },
            {
                "key": "notExistKey",
                "operator": "DoesNotExist"
            },
            {
                "key": "inKey",
                "operator": "In",
                "values": ["goodValue1", "goodValue2"]
            },
            {
                "key": "notInKey",
                "operator": "NotIn",
                "values": ["badValue1, badValue2"]
            }
        ]
    )]}}}}
}


test_pod_multiple_policies_deny {
    count(k8sRequireNetworkPolicy.violation) == 1 with input as generate_pod(
        "default",
        {
            "key": "value",
            "notInKey": "badValue1"
        }
    ) with data.inventory as {"namespace": {"default": {"networking.k8s.io/v1": {"NetworkPolicy": [
        generate_network_policy(
            {
                "key": "value"
            },
            [
                {
                    "key": "inKey",
                    "operator": "In",
                    "values": ["goodValue1", "goodValue2"]
                },
                {
                    "key": "notInKey",
                    "operator": "NotIn",
                    "values": ["badValue1, badValue2"]
                }
            ]
        ),
        generate_network_policy(
            {
                "matchKey": "matchValue"
            },
            [
                {
                    "key": "inKey2",
                    "operator": "In",
                    "values": ["otherGoodValue"]
                },
                {
                    "key": "notInKey2",
                    "operator": "NotIn",
                    "values": ["otherBadValue"]
                }
            ]
        )
    ]}}}}
}

test_pod_multiple_policies_allow {
    count(k8sRequireNetworkPolicy.violation) == 0 with input as generate_pod(
        "default",
        {
            "key": "value",
            "inKey": "goodValue1"
        }
    ) with data.inventory as {"namespace": {"default": {"networking.k8s.io/v1": {"NetworkPolicy": [
        generate_network_policy(
            {
                "key": "value"
            },
            [
                {
                    "key": "inKey",
                    "operator": "In",
                    "values": ["goodValue1", "goodValue2"]
                },
                {
                    "key": "notInKey",
                    "operator": "NotIn",
                    "values": ["badValue1, badValue2"]
                }
            ]
        ),
        generate_network_policy(
            {
                "matchKey": "matchValue"
            },
            [
                {
                    "key": "inKey2",
                    "operator": "In",
                    "values": ["otherGoodValue"]
                },
                {
                    "key": "notInKey2",
                    "operator": "NotIn",
                    "values": ["otherBadValue"]
                }
            ]
        )
    ]}}}}
}

# Deleting should be allowed to prevent race conditions
test_pod_delete {
    count(k8sRequireNetworkPolicy.violation) == 0 with input as generate_pod_being_deleted(
        "default",
        {
            "wrongKey": "value"
        }
    ) with data.inventory as {"namespace": {"default": {"networking.k8s.io/v1": {"NetworkPolicy": []}}}}
}

kinds := [
    "Deployment",
    "StatefulSet",
    "DaemonSet",
    "ReplicaSet",
    "Job",
    "ReplicationController"
]

test_resource_controller_deny {
    res = [test | test = count(k8sRequireNetworkPolicy.violation) == 1 with input as generate_resource_controller(
        kinds[_],
        "default",
        {
            "key": "wrongValue",
            "notInKey": "badValue1"
        }
    ) with data.inventory as {"namespace": {"default": {"networking.k8s.io/v1": {"NetworkPolicy": [generate_network_policy(
        {
            "key": "value",
            "matchKey": "matchValue"
        },
        [
            {
                "key": "inKey",
                "operator": "In",
                "values": ["goodValue1", "goodValue2"]
            },
            {
                "key": "notInKey",
                "operator": "NotIn",
                "values": ["badValue1, badValue2"]
            }
        ]
    )]}}}}]
    all(res)
}

test_resource_controller_allow {
    res = [test | test = count(k8sRequireNetworkPolicy.violation) == 0 with input as generate_resource_controller(
        kinds[_],
        "default",
        {
            "key": "value",
            "matchKey": "matchValue",
            "inKey": "goodValue1"
        }
    ) with data.inventory as {"namespace": {"default": {"networking.k8s.io/v1": {"NetworkPolicy": [generate_network_policy(
        {
            "key": "value",
            "matchKey": "matchValue"
        },
        [
            {
                "key": "inKey",
                "operator": "In",
                "values": ["goodValue1", "goodValue2"]
            },
            {
                "key": "notInKey",
                "operator": "NotIn",
                "values": ["badValue1, badValue2"]
            }
        ]
    )]}}}}]
    all(res)
}

test_cronJob_deny {
    count(k8sRequireNetworkPolicy.violation) == 1 with input as generate_cronJob(
        "default",
        {
            "key": "wrongValue",
            "notInKey": "badValue1"
        }
    ) with data.inventory as {"namespace": {"default": {"networking.k8s.io/v1": {"NetworkPolicy": [generate_network_policy(
        {
            "key": "value",
            "matchKey": "matchValue"
        },
        [
            {
                "key": "inKey",
                "operator": "In",
                "values": ["goodValue1", "goodValue2"]
            },
            {
                "key": "notInKey",
                "operator": "NotIn",
                "values": ["badValue1, badValue2"]
            }
        ]
    )]}}}}
}

test_cronJob_allow {
    count(k8sRequireNetworkPolicy.violation) == 0 with input as generate_cronJob(
        "default",
        {
            "key": "value",
            "matchKey": "matchValue",
            "inKey": "goodValue1"
        }
    ) with data.inventory as {"namespace": {"default": {"networking.k8s.io/v1": {"NetworkPolicy": [generate_network_policy(
        {
            "key": "value",
            "matchKey": "matchValue"
        },
        [
            {
                "key": "inKey",
                "operator": "In",
                "values": ["goodValue1", "goodValue2"]
            },
            {
                "key": "notInKey",
                "operator": "NotIn",
                "values": ["badValue1, badValue2"]
            }
        ]
    )]}}}}
}
