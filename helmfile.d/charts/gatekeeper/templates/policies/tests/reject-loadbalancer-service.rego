package test.k8srejectloadbalancerservice

import data.k8srejectloadbalancerservice

test_loadbalancer_service_deny {
    count(k8srejectloadbalancerservice.violation) == 1 with input as {
        "review": {
            "object": {
                "kind": "Service",
                "spec": {
                    "type": "LoadBalancer"
                }
            }
        }
    }
}

test_clusterip_service_allow {
    count(k8srejectloadbalancerservice.violation) == 0 with input as {
        "review": {
            "object": {
                "kind": "Service",
                "spec": {
                    "type": "ClusterIP"
                }
            }
        }
    }
}

test_nodeport_service_allow {
    count(k8srejectloadbalancerservice.violation) == 0 with input as {
        "review": {
            "object": {
                "kind": "Service",
                "spec": {
                    "type": "NodePort"
                }
            }
        }
    }
}

test_default_service_allow {
    count(k8srejectloadbalancerservice.violation) == 0 with input as {
        "review": {
            "object": {
                "kind": "Service",
                "spec": {}
            }
        }
    }
}