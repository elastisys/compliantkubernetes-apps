package k8srejectloadbalancerservice

violation[{"msg": msg}] {
    input.review.object.kind == "Service"; input.review.object.spec.type == "LoadBalancer"
    msg := "Creation of LoadBalancer Service is not supported. Contact your platform administrator for questions about Load Balancers. Read more at https://elastisys.io/welkin/user-guide/safeguards/enforce-no-load-balancer-service/"
}
