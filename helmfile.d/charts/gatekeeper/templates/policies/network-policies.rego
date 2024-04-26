package k8sRequireNetworkPolicy

violation[{"msg": msg}] {
    namespace := input.review.object.metadata.namespace

    res = [x | x := allChecks(data.inventory.namespace[namespace]["networking.k8s.io/v1"]["NetworkPolicy"][_])]
    allowedOperations := [
        "CREATE",
        "UPDATE"
    ]
    input.review.operation == allowedOperations[_]
    all(res) #all networkpolicies failed to match
    msg := sprintf("No matching networkpolicy found. Elastisys Compliant Kubernetes requires that all pods are targeted by NetworkPolicies. Read more at https://elastisys.io/compliantkubernetes/user-guide/safeguards/enforce-networkpolicies/", [])
}

#Check one networkpolicy, returns true if it does not match
allChecks(netwPolicy) = res {
    r1 := matchLabelsMissingKeys(netwPolicy)
    r2 := any(matchLabelsValues(netwPolicy))
    r3 := matchExpressionsExists(netwPolicy)
    r4 := matchExpressionsDoesNotExist(netwPolicy)
    r5 := any(matchExpressionsIn(netwPolicy))
    r6 := any(matchExpressionsNotIn(netwPolicy))
    #return true if any part of the networkpolicy does not match
    res := any({r1, r2, r3, r4, r5, r6})
}


matchLabelsMissingKeys(netwPolicy) = res {
    res3 := {key | netwPolicy.spec.podSelector.matchLabels[key]}
    res4 := {key | get_labels[key]}
    res := count(res3 - res4) != 0
}

matchLabelsValues(netwPolicy) = res {
    res := [x |
        get_labels[key1] != netwPolicy.spec.podSelector.matchLabels[key3];
        x := key1 == key3]
}

matchExpressionsExists(netwPolicy) = res {
    keys := { key |
        netwPolicy.spec.podSelector.matchExpressions[i].operator == "Exists"
        key := netwPolicy.spec.podSelector.matchExpressions[i].key}
    inputKeys := {key | get_labels[key]}
    res := count(keys - inputKeys) != 0
}

matchExpressionsDoesNotExist(netwPolicy) = res {
    keys := { key |
        netwPolicy.spec.podSelector.matchExpressions[i].operator == "DoesNotExist"
        key := netwPolicy.spec.podSelector.matchExpressions[i].key}
    inputKeys := {key | get_labels[key]}
    res := count(keys & inputKeys) != 0
}

matchExpressionsIn(netwPolicy) = res {
    res := [ x |
        netwPolicy.spec.podSelector.matchExpressions[i].operator == "In"
        key := netwPolicy.spec.podSelector.matchExpressions[i].key
        x := false == any([y | y := get_labels[key] == netwPolicy.spec.podSelector.matchExpressions[i].values[_]])]
}

matchExpressionsNotIn(netwPolicy) = res {
    res := [ x |
        netwPolicy.spec.podSelector.matchExpressions[i].operator == "NotIn"
        key := netwPolicy.spec.podSelector.matchExpressions[i].key
        x := any([y | y := get_labels[key] == netwPolicy.spec.podSelector.matchExpressions[i].values[_]])]
}

# Get labels for "Pods"
get_labels = res {
    input.review.object.kind == "Pod"
    res := input.review.object.metadata.labels
}

# Get labels for resources that use pod templates.
get_labels = res {
    kinds := [
        "Deployment",
        "StatefulSet",
        "DaemonSet",
        "ReplicaSet",
        "Job",
        "ReplicationController"
    ]
    input.review.object.kind == kinds[_]

    res := input.review.object.spec.template.metadata.labels
}

# Get labels for "CronJobs"
get_labels = res {
    input.review.object.kind == "CronJob"
    res := input.review.object.spec.jobTemplate.spec.template.metadata.labels
}
