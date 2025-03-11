package test.k8srestrictpoddisruptionbudgets

import data.k8srestrictpoddisruptionbudgets

#
# Help functions
#

generate_pdb(type, limit, namespace, selector) = obj {
    obj := {
        "kind": "PodDisruptionBudget",
        "metadata": {
            "name": "pdb-name",
            "namespace": namespace
        },
        "spec": {
            type: limit,
            "selector": selector
        }
    }
}

generate_pod_controller(kind, replicas, namespace, labels) = obj {
    allowed_kinds := [
        "Deployment",
        "StatefulSet",
        "ReplicaSet",
        "ReplicationController"
    ]
    kind == allowed_kinds[_]
    obj := {
        "kind": kind,
        "metadata": {
            "namespace": namespace,
            "name": "controller-name"
        },
        "spec": {
            "replicas": replicas,
            "template": {
                "metadata": {
                    "labels": labels
                }
            }
        }
    }
}

generate_replicaset_under_deployment(replicas, namespace, labels) = obj {
    obj := {
        "kind": "ReplicaSet",
        "metadata": {
            "namespace": namespace,
            "name": "controller-name",
            "ownerReferences": [
                {
                    "kind": "Deployment"
                }
            ]
        },
        "spec": {
            "replicas": replicas,
            "template": {
                "metadata": {
                    "labels": labels
                }
            }
        }
    }
}

input_wrap(obj) = input {
    input := {"review": {"object": obj}}
}

pod_controller_groups_kinds := [
    {"group": "apps/v1", "kind": "Deployment"},
    {"group": "apps/v1", "kind": "StatefulSet"},
    {"group": "apps/v1", "kind": "ReplicaSet"},
    {"group": "v1", "kind": "ReplicationController"}
]

#
# Tests
#

# --- Test PDB as review object ---

test_ok_pdb_no_pod_maxUnavailable_int {
    count(k8srestrictpoddisruptionbudgets.violation) == 0 with input as input_wrap(generate_pdb(
        "maxUnavailable",
        1,
        "default",
        {"matchLabels": {"key": "val"}}
    ))
}

test_ok_pdb_no_pod_maxUnavailable_percent {
    count(k8srestrictpoddisruptionbudgets.violation) == 0 with input as input_wrap(generate_pdb(
        "maxUnavailable",
        "10%",
        "default",
        {"matchLabels": {"key": "val"}}
    ))
}


test_bad_pdb_no_pod_maxUnavailable_int {
    count(k8srestrictpoddisruptionbudgets.violation) == 1 with input as input_wrap(generate_pdb(
        "maxUnavailable",
        0,
        "default",
        {"matchLabels": {"key": "val"}}
    ))
}

test_bad_pdb_no_pod_maxUnavailable_percent {
    count(k8srestrictpoddisruptionbudgets.violation) == 1 with input as input_wrap(generate_pdb(
        "maxUnavailable",
        "0%",
        "default",
        {"matchLabels": {"key": "val"}}
    ))
}

test_ok_pdb_no_pod_minAvailable_int {
    count(k8srestrictpoddisruptionbudgets.violation) == 0 with input as input_wrap(generate_pdb(
        "minAvailable",
        0,
        "default",
        {"matchLabels": {"key": "val"}}
    ))
}

test_ok_pdb_no_pod_minAvailable_percent {
    count(k8srestrictpoddisruptionbudgets.violation) == 0 with input as input_wrap(generate_pdb(
        "minAvailable",
        "0%",
        "default",
        {"matchLabels": {"key": "val"}}
    ))
}

test_ok_pdb_with_pod_minAvailable_int {
    namespace := "default"
    selector := {"matchLabels": {"key": "val"}}
    labels := {"key": "val"}
    inventories := [inventory | inventory := {"namespace": {namespace: {pod_controller_groups_kinds[i].group: {pod_controller_groups_kinds[i].kind: [generate_pod_controller(
        pod_controller_groups_kinds[i].kind,
        3,
        namespace,
        labels
    )]}}}}]

    res = [test | test = count(k8srestrictpoddisruptionbudgets.violation) == 0
        with input as input_wrap(generate_pdb(
            "minAvailable",
            1,
            namespace,
            selector
        )) with data.inventory as inventories[_]
    ]
    all(res)
    count(res) == 4
}

test_ok_pdb_with_pod_minAvailable_percent {
    namespace := "default"
    selector := {"matchLabels": {"key": "val"}}
    labels := {"key": "val"}
    inventories := [inventory | inventory := {"namespace": {namespace: {pod_controller_groups_kinds[i].group: {pod_controller_groups_kinds[i].kind: [generate_pod_controller(
        pod_controller_groups_kinds[i].kind,
        3,
        namespace,
        labels
    )]}}}}]

    res = [test | test = count(k8srestrictpoddisruptionbudgets.violation) == 0
        with input as input_wrap(generate_pdb(
            "minAvailable",
            "10%",
            namespace,
            selector
        )) with data.inventory as inventories[_]
    ]
    all(res)
    count(res) == 4
}

test_bad_pdb_with_pod_minAvailable_int {
    namespace := "default"
    selector := {"matchLabels": {"key": "val"}}
    labels := {"key": "val"}
    inventories := [inventory | inventory := {"namespace": {namespace: {pod_controller_groups_kinds[i].group: {pod_controller_groups_kinds[i].kind: [generate_pod_controller(
        pod_controller_groups_kinds[i].kind,
        3,
        namespace,
        labels
    )]}}}}]

    res = [test | test = count(k8srestrictpoddisruptionbudgets.violation) == 1
        with input as input_wrap(generate_pdb(
            "minAvailable",
            3,
            namespace,
            selector
        )) with data.inventory as inventories[_]
    ]
    all(res)
    count(res) == 4
}

test_bad_pdb_with_pod_minAvailable_percent {
    namespace := "default"
    selector := {"matchLabels": {"key": "val"}}
    labels := {"key": "val"}
    inventories := [inventory | inventory := {"namespace": {namespace: {pod_controller_groups_kinds[i].group: {pod_controller_groups_kinds[i].kind: [generate_pod_controller(
        pod_controller_groups_kinds[i].kind,
        3,
        namespace,
        labels
    )]}}}}]

    res = [test | test = count(k8srestrictpoddisruptionbudgets.violation) == 1
        with input as input_wrap(generate_pdb(
            "minAvailable",
            "90%",
            namespace,
            selector
        )) with data.inventory as inventories[_]
    ]
    all(res)
    count(res) == 4
}

# --- test pod controller as review object ---

test_ok_pod_controller_maxUnavailable_int {
    namespace := "default"
    selector := {"matchLabels": {"key": "val"}}
    labels := {"key": "val"}
    pod_controllers := [pod_controller | pod_controller = input_wrap(generate_pod_controller(
        pod_controller_groups_kinds[_].kind,
        3,
        namespace,
        labels
    ))]

    res = [test | test = count(k8srestrictpoddisruptionbudgets.violation) == 0
        with input as pod_controllers[_]
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "maxUnavailable",
            1,
            namespace,
            selector
        )]}}}}
    ]
    all(res)
    count(res) == 4
}

test_ok_pod_controller_maxUnavailable_percent {
    namespace := "default"
    selector := {"matchLabels": {"key": "val"}}
    labels := {"key": "val"}
    pod_controllers := [pod_controller | pod_controller = input_wrap(generate_pod_controller(
        pod_controller_groups_kinds[_].kind,
        3,
        namespace,
        labels
    ))]

    res = [test | test = count(k8srestrictpoddisruptionbudgets.violation) == 0
        with input as pod_controllers[_]
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "maxUnavailable",
            "20%",
            namespace,
            selector
        )]}}}}
    ]
    all(res)
    count(res) == 4
}

test_bad_pod_controller_maxUnavailable_int {
    namespace := "default"
    selector := {"matchLabels": {"key": "val"}}
    labels := {"key": "val"}
    pod_controllers := [pod_controller | pod_controller = input_wrap(generate_pod_controller(
        pod_controller_groups_kinds[_].kind,
        3,
        namespace,
        labels
    ))]

    res = [test | test = count(k8srestrictpoddisruptionbudgets.violation) == 1
        with input as pod_controllers[_]
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "maxUnavailable",
            0,
            namespace,
            selector
        )]}}}}
    ]
    all(res)
    count(res) == 4
}

test_bad_pod_controller_maxUnavailable_percent {
    namespace := "default"
    selector := {"matchLabels": {"key": "val"}}
    labels := {"key": "val"}
    pod_controllers := [pod_controller | pod_controller = input_wrap(generate_pod_controller(
        pod_controller_groups_kinds[_].kind,
        3,
        namespace,
        labels
    ))]

    res = [test | test = count(k8srestrictpoddisruptionbudgets.violation) == 1
        with input as pod_controllers[_]
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "maxUnavailable",
            "0%",
            namespace,
            selector
        )]}}}}
    ]
    all(res)
    count(res) == 4
}

test_ok_pod_controller_minAvailable_int {
    namespace := "default"
    selector := {"matchLabels": {"key": "val"}}
    labels := {"key": "val"}
    pod_controllers := [pod_controller | pod_controller = input_wrap(generate_pod_controller(
        pod_controller_groups_kinds[_].kind,
        3,
        namespace,
        labels
    ))]

    res = [test | test = count(k8srestrictpoddisruptionbudgets.violation) == 0
        with input as pod_controllers[_]
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "minAvailable",
            1,
            namespace,
            selector
        )]}}}}
    ]
    all(res)
    count(res) == 4
}

test_ok_pod_controller_minAvailable_percent {
    namespace := "default"
    selector := {"matchLabels": {"key": "val"}}
    labels := {"key": "val"}
    pod_controllers := [pod_controller | pod_controller = input_wrap(generate_pod_controller(
        pod_controller_groups_kinds[_].kind,
        3,
        namespace,
        labels
    ))]

    res = [test | test = count(k8srestrictpoddisruptionbudgets.violation) == 0
        with input as pod_controllers[_]
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "minAvailable",
            "20%",
            namespace,
            selector
        )]}}}}
    ]
    all(res)
    count(res) == 4
}

test_bad_pod_controller_minAvailable_int {
    namespace := "default"
    selector := {"matchLabels": {"key": "val"}}
    labels := {"key": "val"}
    pod_controllers := [pod_controller | pod_controller = input_wrap(generate_pod_controller(
        pod_controller_groups_kinds[_].kind,
        3,
        namespace,
        labels
    ))]

    res = [test | test = count(k8srestrictpoddisruptionbudgets.violation) == 1
        with input as pod_controllers[_]
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "minAvailable",
            5,
            namespace,
            selector
        )]}}}}
    ]
    all(res)
    count(res) == 4
}

test_bad_pod_controller_minAvailable_percent {
    namespace := "default"
    selector := {"matchLabels": {"key": "val"}}
    labels := {"key": "val"}
    pod_controllers := [pod_controller | pod_controller = input_wrap(generate_pod_controller(
        pod_controller_groups_kinds[_].kind,
        3,
        namespace,
        labels
    ))]

    res = [test | test = count(k8srestrictpoddisruptionbudgets.violation) == 1
        with input as pod_controllers[_]
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "minAvailable",
            "90%",
            namespace,
            selector
        )]}}}}
    ]
    all(res)
    count(res) == 4
}

# --- Test replicaset under deployment as review object ---

test_bad_replicaset_under_deployment_maxUnavailable_int {
    namespace := "default"
    selector := {"matchLabels": {"key": "val"}}
    labels := {"key": "val"}

    # The replicaset and PDB does not allow for disruption, but this should not violate since replicaset is under control of a deployment
    count(k8srestrictpoddisruptionbudgets.violation) == 0
        with input as input_wrap(generate_replicaset_under_deployment(
            3,
            namespace,
            labels
        ))
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "maxUnavailable",
            0,
            namespace,
            selector
    )]}}}}
}

test_bad_replicaset_under_deployment_minAvailable_int {
    namespace := "default"
    selector := {"matchLabels": {"key": "val"}}
    labels := {"key": "val"}

    # The replicaset and PDB does not allow for disruption, but this should not violate since replicaset is under control of a deployment
    count(k8srestrictpoddisruptionbudgets.violation) == 0
        with input as input_wrap(generate_replicaset_under_deployment(
            3,
            namespace,
            labels
        ))
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "minAvailable",
            3,
            namespace,
            selector
    )]}}}}
}

# --- Test different selectors ---

test_matching_match_labels {
    namespace := "default"
    selector := {"matchLabels": {"key": "val"}}
    labels := {"key": "val"}

    count(k8srestrictpoddisruptionbudgets.violation) == 1
        with input as input_wrap(generate_pod_controller(
            "Deployment",
            3,
            namespace,
            labels
        ))
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "minAvailable",
            3,
            namespace,
            selector
    )]}}}}
}

test_matching_match_labels {
    namespace := "default"
    selector := {"matchLabels": {"key": "val", "key2": "val2"}}
    labels := {"key": "val", "key2": "val2"}

    count(k8srestrictpoddisruptionbudgets.violation) == 1
        with input as input_wrap(generate_pod_controller(
            "Deployment",
            3,
            namespace,
            labels
        ))
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "minAvailable",
            3,
            namespace,
            selector
    )]}}}}
}

test_mismatching_match_labels_wrong_key {
    namespace := "default"
    selector := {"matchLabels": {"key": "val", "wrong_key": "val2"}}
    labels := {"key": "val", "key2": "val2"}

    count(k8srestrictpoddisruptionbudgets.violation) == 0
        with input as input_wrap(generate_pod_controller(
            "Deployment",
            3,
            namespace,
            labels
        ))
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "minAvailable",
            3,
            namespace,
            selector
    )]}}}}
}

test_mismatching_match_labels_wrong_val {
    namespace := "default"
    selector := {"matchLabels": {"key": "val", "key2": "wrong_val"}}
    labels := {"key": "val", "key2": "val2"}

    count(k8srestrictpoddisruptionbudgets.violation) == 0
        with input as input_wrap(generate_pod_controller(
            "Deployment",
            3,
            namespace,
            labels
        ))
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "minAvailable",
            3,
            namespace,
            selector
    )]}}}}
}

test_matching_match_expression_exists {
    namespace := "default"
    selector := {"matchExpression": [{"key": "key", "operator": "Exists"}]}
    labels := {"key": "val", "key2": "val2"}

    count(k8srestrictpoddisruptionbudgets.violation) == 1
        with input as input_wrap(generate_pod_controller(
            "Deployment",
            3,
            namespace,
            labels
        ))
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "minAvailable",
            3,
            namespace,
            selector
    )]}}}}
}

test_mismatching_match_expression_exists {
    namespace := "default"
    selector := {"matchExpressions": [{"key": "wrong_key", "operator": "Exists"}]}
    labels := {"key": "val", "key2": "val2"}

    count(k8srestrictpoddisruptionbudgets.violation) == 0
        with input as input_wrap(generate_pod_controller(
            "Deployment",
            3,
            namespace,
            labels
        ))
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "minAvailable",
            3,
            namespace,
            selector
    )]}}}}
}

test_matching_match_expression_does_not_exist {
    namespace := "default"
    selector := {"matchExpression": [{"key": "other_key", "operator": "DoesNotExist"}]}
    labels := {"key": "val", "key2": "val2"}

    count(k8srestrictpoddisruptionbudgets.violation) == 1
        with input as input_wrap(generate_pod_controller(
            "Deployment",
            3,
            namespace,
            labels
        ))
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "minAvailable",
            3,
            namespace,
            selector
    )]}}}}
}

test_mismatching_match_expression_does_not_exist {
    namespace := "default"
    selector := {"matchExpressions": [{"key": "key", "operator": "DoesNotExist"}]}
    labels := {"key": "val", "key2": "val2"}

    count(k8srestrictpoddisruptionbudgets.violation) == 0
        with input as input_wrap(generate_pod_controller(
            "Deployment",
            3,
            namespace,
            labels
        ))
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "minAvailable",
            3,
            namespace,
            selector
    )]}}}}
}

test_matching_match_expression_in {
    namespace := "default"
    selector := {"matchExpressions": [{"key": "key", "operator": "In", "values": ["val"]}]}
    labels := {"key": "val", "key2": "val2"}
    count(k8srestrictpoddisruptionbudgets.violation) == 1
        with input as input_wrap(generate_pod_controller(
            "Deployment",
            3,
            namespace,
            labels
        ))
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "minAvailable",
            3,
            namespace,
            selector
    )]}}}}
}

test_mismatching_match_expression_in_wrong_key {
    namespace := "default"
    selector := {"matchExpressions": [{"key": "wrong_key", "operator": "In", "values": ["val"]}]}
    labels := {"key": "val", "key2": "val2"}

    count(k8srestrictpoddisruptionbudgets.violation) == 0
        with input as input_wrap(generate_pod_controller(
            "Deployment",
            3,
            namespace,
            labels
        ))
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "minAvailable",
            3,
            namespace,
            selector
    )]}}}}
}

test_mismatching_match_expression_in_wrong_val {
    namespace := "default"
    selector := {"matchExpressions": [{"key": "wrong_key", "operator": "In", "values": ["wrong_val"]}]}
    labels := {"key": "val", "key2": "val2"}

    count(k8srestrictpoddisruptionbudgets.violation) == 0
        with input as input_wrap(generate_pod_controller(
            "Deployment",
            3,
            namespace,
            labels
        ))
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "minAvailable",
            3,
            namespace,
            selector
    )]}}}}
}

test_matching_match_expression_not_in_other_key {
    namespace := "default"
    selector := {"matchExpressions": [{"key": "other_key", "operator": "NotIn", "values": ["val"]}]}
    labels := {"key": "val", "key2": "val2"}
    count(k8srestrictpoddisruptionbudgets.violation) == 1
        with input as input_wrap(generate_pod_controller(
            "Deployment",
            3,
            namespace,
            labels
        ))
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "minAvailable",
            3,
            namespace,
            selector
    )]}}}}
}

test_matching_match_expression_not_in_other_val {
    namespace := "default"
    selector := {"matchExpressions": [{"key": "key", "operator": "NotIn", "values": ["other_val"]}]}
    labels := {"key": "val", "key2": "val2"}
    count(k8srestrictpoddisruptionbudgets.violation) == 1
        with input as input_wrap(generate_pod_controller(
            "Deployment",
            3,
            namespace,
            labels
        ))
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "minAvailable",
            3,
            namespace,
            selector
    )]}}}}
}

test_mismatching_match_expression_not_in {
    namespace := "default"
    selector := {"matchExpressions": [{"key": "key", "operator": "NotIn", "values": ["val"]}]}
    labels := {"key": "val", "key2": "val2"}

    count(k8srestrictpoddisruptionbudgets.violation) == 0
        with input as input_wrap(generate_pod_controller(
            "Deployment",
            3,
            namespace,
            labels
        ))
        with data.inventory as {"namespace": {namespace: {"policy/v1": {"PodDisruptionBudget": [generate_pdb(
            "minAvailable",
            3,
            namespace,
            selector
    )]}}}}
}
