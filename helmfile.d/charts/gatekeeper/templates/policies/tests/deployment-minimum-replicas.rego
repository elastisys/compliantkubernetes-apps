package test.k8sminimumreplicas

import data.k8sminimumreplicas

test_deployment_insufficient_replicas_deny {
    count(k8sminimumreplicas.violation) == 1 with input as {
        "review": {
            "kind": {
                "kind": "Deployment"
            },
            "object": {
                "kind": "Deployment",
                "metadata": {
                    "name": "test-deployment"
                },
                "spec": {
                    "replicas": 1
                }
            }
        },
        "parameters": {
            "min_replicas": 2,
            "annotation": "elastisys.io/ignore-minimum-replicas"
        }
    }
}

test_deployment_zero_replicas_deny {
    count(k8sminimumreplicas.violation) == 1 with input as {
        "review": {
            "kind": {
                "kind": "Deployment"
            },
            "object": {
                "kind": "Deployment",
                "metadata": {
                    "name": "test-deployment"
                },
                "spec": {
                    "replicas": 0
                }
            }
        },
        "parameters": {
            "min_replicas": 2,
            "annotation": "elastisys.io/ignore-minimum-replicas"
        }
    }
}

test_deployment_sufficient_replicas_allow {
    count(k8sminimumreplicas.violation) == 0 with input as {
        "review": {
            "kind": {
                "kind": "Deployment"
            },
            "object": {
                "kind": "Deployment",
                "metadata": {
                    "name": "test-deployment"
                },
                "spec": {
                    "replicas": 2
                }
            }
        },
        "parameters": {
            "min_replicas": 2,
            "annotation": "elastisys.io/ignore-minimum-replicas"
        }
    }
}

test_deployment_excess_replicas_allow {
    count(k8sminimumreplicas.violation) == 0 with input as {
        "review": {
            "kind": {
                "kind": "Deployment"
            },
            "object": {
                "kind": "Deployment",
                "metadata": {
                    "name": "test-deployment"
                },
                "spec": {
                    "replicas": 5
                }
            }
        },
        "parameters": {
            "min_replicas": 2,
            "annotation": "elastisys.io/ignore-minimum-replicas"
        }
    }
}

test_deployment_with_override_annotation_allow {
    count(k8sminimumreplicas.violation) == 0 with input as {
        "review": {
            "kind": {
                "kind": "Deployment"
            },
            "object": {
                "kind": "Deployment",
                "metadata": {
                    "name": "test-deployment",
                    "annotations": {
                        "elastisys.io/ignore-minimum-replicas": "true"
                    }
                },
                "spec": {
                    "replicas": 1
                }
            }
        },
        "parameters": {
            "min_replicas": 2,
            "annotation": "elastisys.io/ignore-minimum-replicas"
        }
    }
}

test_statefulset_insufficient_replicas_deny {
    count(k8sminimumreplicas.violation) == 1 with input as {
        "review": {
            "kind": {
                "kind": "StatefulSet"
            },
            "object": {
                "kind": "StatefulSet",
                "metadata": {
                    "name": "test-statefulset"
                },
                "spec": {
                    "replicas": 1
                }
            }
        },
        "parameters": {
            "min_replicas": 2,
            "annotation": "elastisys.io/ignore-minimum-replicas"
        }
    }
}

test_statefulset_sufficient_replicas_allow {
    count(k8sminimumreplicas.violation) == 0 with input as {
        "review": {
            "kind": {
                "kind": "StatefulSet"
            },
            "object": {
                "kind": "StatefulSet",
                "metadata": {
                    "name": "test-statefulset"
                },
                "spec": {
                    "replicas": 2
                }
            }
        },
        "parameters": {
            "min_replicas": 2,
            "annotation": "elastisys.io/ignore-minimum-replicas"
        }
    }
}

test_statefulset_with_override_annotation_allow {
    count(k8sminimumreplicas.violation) == 0 with input as {
        "review": {
            "kind": {
                "kind": "StatefulSet"
            },
            "object": {
                "kind": "StatefulSet",
                "metadata": {
                    "name": "test-statefulset",
                    "annotations": {
                        "elastisys.io/ignore-minimum-replicas": "true"
                    }
                },
                "spec": {
                    "replicas": 1
                }
            }
        },
        "parameters": {
            "min_replicas": 2,
            "annotation": "elastisys.io/ignore-minimum-replicas"
        }
    }
}