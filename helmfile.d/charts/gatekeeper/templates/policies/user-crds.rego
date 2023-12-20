package k8susercrds

# Check when there are no valid reviews
violation[{"msg": msg}] {
    review := input.review
    fetchFailedReviews[_]

    not any(validUser)

    msg := sprintf("User <%v> is not allowed to <%v> CRD %v", [review.userInfo.username, review.operation, review.object.metadata.name])
}

validUser[v] {
    review := input.review
    v := input.parameters.users[_] == review.userInfo.username
}

validUser[v] {
    review := input.review
    v := input.parameters.groups[_] == review.userInfo.groups[_]
}

validUser[v] {
    review := input.review

    some i
    serviceAccount := input.parameters.serviceAccounts[i]
    serviceAccount.name == "*"
    regexString := replace("system:serviceaccount:{namespace}:", "{namespace}", serviceAccount.namespace)
    v := regex.match(regexString, review.userInfo.username)
}
validUser[v] {
    review := input.review

    some i
    allowedServiceAccount := input.parameters.serviceAccounts[i]
    replace_part_1 := replace("system:serviceaccount:{namespace}:{name}", "{namespace}", allowedServiceAccount.namespace)
    serviceAccountString := replace(replace_part_1, "{name}", allowedServiceAccount.name)
    v := serviceAccountString == review.userInfo.username
}

# Fetch reivews with disallowed crds
fetchFailedReviews[r]{
    review := input.review

    review.object.kind == "CustomResourceDefinition"

    not any(validCRDNames)

    allowedCRDs := input.parameters.allowedCRDs

    r := review
}

fetchFailedReviews[r]{
    review := input.review

    count(input.parameters.allowedCRDs) == 0

    r := review
}

# Allow just listed crds
validCRDNames[allowed] {
    review := input.review
    allowedCRDs := input.parameters.allowedCRDs

    some i
    allowedCRDs[i].group == review.object.spec.group
    allowedCRDs[i].names[_] == review.object.metadata.name
    allowed := true
}

# Allow all crds
validCRDNames[allowed] {
    review := input.review
    allowedCRDs := input.parameters.allowedCRDs

    some i
    allowedCRDs[i].group == review.object.spec.group
    allowedCRDs[i].names[_] == "*"
    allowed := true
}
