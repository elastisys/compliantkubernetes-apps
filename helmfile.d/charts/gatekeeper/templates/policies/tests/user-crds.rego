package test.k8susercrds

import data.k8susercrds

test_allowed_CRD_as_Admin_user {
    count(k8susercrds.violation) == 0 with input as {
        "review": {
            "object": {
                "kind": "CustomResourceDefinition",
                "metadata": {"name": "sealedsecrets.bitnami.com"},
                "spec": {"group": "bitnami.com"},
            },
            "operation": "APPLY",
            "userInfo": {
                "username": "robin",
                "groups": [""],
            },
        },
        "parameters": {
            "users": ["robin"],
            "groups": [],
            "allowedCRDs": [],
        },
    }
}

test_allowed_CRD_as_Admin_group {
    count(k8susercrds.violation) == 0 with input as {
        "review": {
            "object": {
                "kind": "CustomResourceDefinition",
                "metadata": {"name": "sealedsecrets.bitnami.com"},
                "spec": {"group": "bitnami.com"},
            },
            "operation": "APPLY",
            "userInfo": {
                "username": "robin",
                "groups": ["admin"],
            },
        },
        "parameters": {
            "users": [],
            "groups": ["admin"],
            "allowedCRDs": [],
        },
    }
}

test_not_allowed_CRD_no_users_no_groups_no_CRDS {
    count(k8susercrds.violation) == 1 with input as {
        "review": {
            "object": {
                "kind": "CustomResourceDefinition",
                "metadata": {"name": "sealedsecrets.bitnami.com"},
                "spec": {"group": "bitnami.com"},
            },
            "operation": "APPLY",
            "userInfo": {
                "username": "robin",
                "groups": ["admin"],
            },
        },
        "parameters": {
            "users": [],
            "groups": [],
            "allowedCRDs": [],
        },
    }
}

test_allowed_CRD_no_users_no_groups {
    count(k8susercrds.violation) == 0 with input as {
        "review": {
            "object": {
                "kind": "CustomResourceDefinition",
                "metadata": {"name": "sealedsecrets.bitnami.com"},
                "spec": {"group": "bitnami.com"},
            },
            "operation": "APPLY",
            "userInfo": {
                "username": "robin",
                "groups": ["admin"],
            },
        },
        "parameters": {
            "users": [],
            "groups": [],
            "allowedCRDs": [{
                "group": "bitnami.com",
                "names": ["sealedsecrets.bitnami.com"],
            }],
        },
    }
}

test_allowed_two_CRD_no_users_no_groups {
    count(k8susercrds.violation) == 0 with input as {
        "review": {
            "object": {
                "kind": "CustomResourceDefinition",
                "metadata": {"name": "sealedsecrets.bitnami.com"},
                "spec": {"group": "bitnami.com"},
            },
            "operation": "APPLY",
            "userInfo": {
                "username": "robin",
                "groups": ["admin"],
            },
        },
        "parameters": {
            "users": [],
            "groups": [],
            "allowedCRDs": [
                {
                    "group": "bitnami.com",
                    "names": ["sealedsecrets.bitnami.com"],
                },
                {
                    "group": "bitnami2.com",
                    "names": ["sealedsecrets.bitnami2.com"],
                },
            ],
        },
    }
}

test_not_allowed_two_CRD_no_users_no_groups {
    count(k8susercrds.violation) == 1 with input as {
        "review": {
            "object": {
                "kind": "CustomResourceDefinition",
                "metadata": {"name": "sealedsecrets.bitnami3.com"},
                "spec": {"group": "bitnami3.com"},
            },
            "operation": "APPLY",
            "userInfo": {
                "username": "robin",
                "groups": ["admin"],
            },
        },
        "parameters": {
            "users": [],
            "groups": [],
            "allowedCRDs": [
                {
                    "group": "bitnami.com",
                    "names": ["sealedsecrets.bitnami.com"],
                },
                {
                    "group": "bitnami2.com",
                    "names": ["sealedsecrets.bitnami2.com"],
                },
            ],
        },
    }
}

test_not_allowed_CRD_no_users_no_groups_wrong_CRD_name {
    count(k8susercrds.violation) == 1 with input as {
        "review": {
            "object": {
                "kind": "CustomResourceDefinition",
                "metadata": {"name": "sealedsecrets.bitnami.com"},
                "spec": {"group": "bitnami.com"},
            },
            "operation": "APPLY",
            "userInfo": {
                "username": "robin",
                "groups": ["admin"],
            },
        },
        "parameters": {
            "users": [],
            "groups": [],
            "allowedCRDs": [{
                "group": "bitnami.com",
                "names": ["sealedsecrets2.bitnami.com"],
            }],
        },
    }
}

test_not_allowed_CRD_no_users_no_groups_wrong_CRD_group {
    count(k8susercrds.violation) == 1 with input as {
        "review": {
            "object": {
                "kind": "CustomResourceDefinition",
                "metadata": {"name": "sealedsecrets.bitnami.com"},
                "spec": {"group": "bitnami.com"},
            },
            "operation": "APPLY",
            "userInfo": {
                "username": "robin",
                "groups": ["admin"],
            },
        },
        "parameters": {
            "users": [],
            "groups": [],
            "allowedCRDs": [{
                "group": "bitnami2.com",
                "names": ["sealedsecrets.bitnami.com"],
            }],
        },
    }
}

test_allowed_namespace_serivceaccount {
    count(k8susercrds.violation) == 0 with input as {
        "review": {
            "object": {
                "kind": "CustomResourceDefinition",
                "metadata": {"name": "sealedsecrets.bitnami.com"},
                "spec": {"group": "bitnami.com"},
            },
            "operation": "APPLY",
            "userInfo": {
                "username": "system:serviceaccount:gatekeeper-system:gatekeeper-admin-upgrade-crds",
                "groups": [],
            },
        },
        "parameters": {
            "users": [],
            "groups": [],
            "serviceAccounts": [{"namespace": "gatekeeper-system", "name": "*"}],
            "allowedCRDs": [{
                "group": "bitnami2.com",
                "names": ["sealedsecrets.bitnami.com"],
            }],
        },
    }
}

test_not_allowed_namespace_serivceaccount {
    count(k8susercrds.violation) == 1 with input as {
        "review": {
            "object": {
                "kind": "CustomResourceDefinition",
                "metadata": {"name": "sealedsecrets.bitnami.com"},
                "spec": {"group": "bitnami.com"},
            },
            "operation": "APPLY",
            "userInfo": {
                "username": "system:serviceaccount:user-namespace:gatekeeper-admin-upgrade-crds",
                "groups": [],
            },
        },
        "parameters": {
            "users": [],
            "groups": [],
            "serviceAccounts": [{"namespace": "gatekeeper-system", "name": "*"}],
            "allowedCRDs": [{
                "group": "bitnami2.com",
                "names": ["sealedsecrets.bitnami.com"],
            }],
        },
    }
}
test_allowed_namespace_name_serivceaccount {
    count(k8susercrds.violation) == 0 with input as {
        "review": {
            "object": {
                "kind": "CustomResourceDefinition",
                "metadata": {"name": "sealedsecrets.bitnami.com"},
                "spec": {"group": "bitnami.com"},
            },
            "operation": "APPLY",
            "userInfo": {
                "username": "system:serviceaccount:gatekeeper-system:gatekeeper-admin-upgrade-crds",
                "groups": [],
            },
        },
        "parameters": {
            "users": [],
            "groups": [],
            "serviceAccounts": [{"namespace": "gatekeeper-system", "name": "gatekeeper-admin-upgrade-crds"}],
            "allowedCRDs": [{
                "group": "bitnami2.com",
                "names": ["sealedsecrets.bitnami.com"],
            }],
        },
    }
}
test_not_allowed_namespace_name_serivceaccount {
    count(k8susercrds.violation) == 1 with input as {
        "review": {
            "object": {
                "kind": "CustomResourceDefinition",
                "metadata": {"name": "sealedsecrets.bitnami.com"},
                "spec": {"group": "bitnami.com"},
            },
            "operation": "APPLY",
            "userInfo": {
                "username": "system:serviceaccount:gatekeeper-system:gatekeeper-admin-upgrade-crds",
                "groups": [],
            },
        },
        "parameters": {
            "users": [],
            "groups": [],
            "serviceAccounts": [{"namespace": "gatekeeper-system", "name": "not-correct-name"}],
            "allowedCRDs": [{
                "group": "bitnami2.com",
                "names": ["sealedsecrets.bitnami.com"],
            }],
        },
    }
}
test_not_allowed_allowedCRDs_null {
    count(k8susercrds.violation) == 1 with input as {
        "review": {
            "object": {
                "kind": "CustomResourceDefinition",
                "metadata": {"name": "sealedsecrets.bitnami.com"},
                "spec": {"group": "bitnami.com"},
            },
            "operation": "APPLY",
            "userInfo": {
                "username": "system:serviceaccount:user-namespace:gatekeeper-admin-upgrade-crds",
                "groups": [],
            },
        },
        "parameters": {
            "users": [],
            "groups": [],
            "serviceAccounts": [{"namespace": "gatekeeper-system", "name": "*"}],
            "allowedCRDs": null,
        },
    }
}
