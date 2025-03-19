package k8srestrictpoddisruptionbudgets

# Reject PDB if maxUnavailable does not allow at least 1 pod disruption
violation[{"msg": msg}] {
    input.review.object.kind == "PodDisruptionBudget"
    pdb := input.review.object

    pdb.spec.maxUnavailable

    not_valid_pdb_max_unavailable(pdb)
    # TODO update messages with link to public docs
    msg := sprintf(
    "PodDisruptionBudget rejected: PodDisruptionBudget <%v> has maxUnavailable of %v, only positive integers or percentages are allowed for maxUnavailable",
    [pdb.metadata.name, pdb.spec.maxUnavailable],
    )
}

# Reject PDB if minAvailable does not allow at least 1 pod disruption
violation[{"msg": msg}] {
    input.review.object.kind == "PodDisruptionBudget"
    pdb := input.review.object

    pdb.spec.minAvailable

	# TODO add support for replicationcontroller group "v1" and restrict to just the four kinds
    objs := [controllers | controllers := data.inventory.namespace[pdb.metadata.namespace]["apps/v1"][_]]
    obj := objs[_][_]

    not mismatched_selector(pdb, obj)

    not_valid_pdb_min_available(obj, pdb)
    not replica_set_under_deployment(obj)

    msg := sprintf(
    "PodDisruptionBudget rejected: %v <%v> has %v replica(s) but PodDisruptionBudget <%v> has minAvailable of %v, minAvailable should always be lower than replica(s), and not used when replica(s) is set to 1.",
    [obj.kind, obj.metadata.name, obj.spec.replicas, pdb.metadata.name, pdb.spec.minAvailable],
    )
}

# Reject pod controller if connected PDBs maxUnavailable does not allow at least 1 pod disruption
violation[{"msg": msg}] {
    input.review.object.kind == podControllerKinds[_]
    obj := input.review.object
    not replica_set_under_deployment(obj)

    pdb := data.inventory.namespace[obj.metadata.namespace]["policy/v1"].PodDisruptionBudget[_]

    pdb.spec.maxUnavailable

    not mismatched_selector(pdb, obj)

    not_valid_pdb_max_unavailable(pdb)
    msg := sprintf(
    "%v rejected: %v <%v> has been selected by PodDisruptionBudget <%v> but has maxUnavailable of %v, only positive integers or percentages are allowed for maxUnavailable",
    [obj.kind, obj.kind, obj.metadata.name, pdb.metadata.name, pdb.spec.maxUnavailable],
    )
}

# Reject pod controller if connected PDBs minAvailable does not allow at least 1 pod disruption
violation[{"msg": msg}] {
    input.review.object.kind == podControllerKinds[_]
    obj := input.review.object
    not replica_set_under_deployment(obj)

    pdb := data.inventory.namespace[obj.metadata.namespace]["policy/v1"].PodDisruptionBudget[_]

    pdb.spec.minAvailable

    not mismatched_selector(pdb, obj)

    not_valid_pdb_min_available(obj, pdb)
    msg := sprintf(
    "%v rejected: %v <%v> has %v replica(s) but PodDisruptionBudget <%v> has minAvailable of %v, minAvailable should always be lower than replica(s), and not used when replica(s) is set to 1.",
    [obj.kind, obj.kind, obj.metadata.name, obj.spec.replicas, pdb.metadata.name, pdb.spec.minAvailable],
    )
}

# The type of pod controller to validate
podControllerKinds := [
    "Deployment",
    "StatefulSet",
    "ReplicaSet",
    "ReplicationController"
]

# Do not reject replicasets that are controlled by deployment, instead reject the deploymentd
replica_set_under_deployment(obj) {
    obj.kind == "ReplicaSet"
    count([i | obj.metadata.ownerReferences[i].kind == "Deployment"]) > 0
}

# Check minAvailable if it is integer
not_valid_pdb_min_available(obj, pdb) {
    not regex.match("^[0-9]+%$", pdb.spec.minAvailable)
    obj.spec.replicas <= pdb.spec.minAvailable
}

# Check minAvailable if it is percentage
not_valid_pdb_min_available(obj, pdb) {
    replicas := obj.spec.replicas
    regex.match("^[0-9]+%$", pdb.spec.minAvailable)
    percentage_num := to_number(replace(pdb.spec.minAvailable, "%", ""))
    min_available := ceil((percentage_num/100)*replicas)

    replicas <= min_available
}

not_valid_pdb_max_unavailable(pdb) {
    pdb.spec.maxUnavailable == 0
}

not_valid_pdb_max_unavailable(pdb) {
    pdb.spec.maxUnavailable == "0%"
}

# Check one podDisruptionBudget and pod(controller), returns true if it does not match
mismatched_selector(pdb, obj) = res {
    r1 := match_labels(pdb, obj)
    r2 := match_expressions_exists(pdb, obj)
    r3 := match_expressions_does_not_exist(pdb, obj)
    r4 := any(match_expressions_in(pdb, obj))
    r5 := any(match_expressions_not_in(pdb, obj))
    # Return true if any part of the podDisruptionBudget and pod(controller) does not match
    res := any({r1, r2, r3, r4, r5})
}

match_labels(pdb, obj) = res {
    pdb_match_labels := { [label, value] | some label; value := pdb.spec.selector.matchLabels[label] }
    obj_match_labels := { [label, value] | some label; value := obj.spec.selector.matchLabels[label] }
    res := count(pdb_match_labels - obj_match_labels) != 0
}

match_expressions_exists(pdb, obj) = res {
    keys := { key |
        pdb.spec.selector.matchExpressions[i].operator == "Exists"
        key := pdb.spec.selector.matchExpressions[i].key}
    inputKeys := {key | get_labels(obj)[key]}
    res := count(keys - inputKeys) != 0
}

match_expressions_does_not_exist(pdb, obj) = res {
    keys := { key |
        pdb.spec.selector.matchExpressions[i].operator == "DoesNotExist"
        key := pdb.spec.selector.matchExpressions[i].key}
    inputKeys := {key | get_labels(obj)[key]}
    res := count(keys & inputKeys) != 0
}

match_expressions_in(pdb, obj) = res {
    res := [ x |
        pdb.spec.selector.matchExpressions[i].operator == "In"
        key := pdb.spec.selector.matchExpressions[i].key
        x := false == any([y | y := get_labels(obj)[key] == pdb.spec.selector.matchExpressions[i].values[_]])]
}

match_expressions_not_in(pdb, obj) = res {
    res := [ x |
        pdb.spec.selector.matchExpressions[i].operator == "NotIn"
        key := pdb.spec.selector.matchExpressions[i].key
        x := any([y | y := get_labels(obj)[key] == pdb.spec.selector.matchExpressions[i].values[_]])]
}

# Get labels for resources that use pod templates.
get_labels(obj) = res {
    kinds := [
        "Deployment",
        "StatefulSet",
        "ReplicaSet",
        "ReplicationController"
    ]
    obj.kind == kinds[_]

    res := obj.spec.template.metadata.labels
}
