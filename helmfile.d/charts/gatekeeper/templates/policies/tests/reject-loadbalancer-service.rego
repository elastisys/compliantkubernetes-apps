package test.k8srejectloadbalancerservice

import data.k8srejectloadbalancerservice

#
# Helper functions
#
generate_service(service_type) = obj {
    obj := {
        "review": {
            "object": {
                "kind": "Service",
                "metadata": {
                    "name": "test-service"
                },
                "spec": {
                    "type": service_type
                }
            }
        }
    }
}

#
# Tests
#

# Service with type LoadBalancer should trigger violation
test_loadbalancer_service_deny {
    count(k8srejectloadbalancerservice.violation) == 1 with input as generate_service("LoadBalancer")
}

# Service with type ClusterIP should be allowed
test_clusterip_service_allow {
    count(k8srejectloadbalancerservice.violation) == 0 with input as generate_service("ClusterIP")
}

# Service with type NodePort should be allowed
test_nodeport_service_allow {
    count(k8srejectloadbalancerservice.violation) == 0 with input as generate_service("NodePort")
}

# Service with type ExternalName should be allowed
test_externalname_service_allow {
    count(k8srejectloadbalancerservice.violation) == 0 with input as generate_service("ExternalName")
}
