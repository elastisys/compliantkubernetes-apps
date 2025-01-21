package k8spreventaccidentaldeletion

import future.keywords.every

prevented_kinds := ["Cluster", "OpenStackCluster", "AzureCluster"]

test_delete_resource_without_annotation_is_denied {
    every i in prevented_kinds {
        count(violation) == 1 with input as {
            "review": {
                "operation": "DELETE",
                "object": {
                    "apiVersion": "*",
                    "kind": i,
                    "metadata": {
                        "name": "test-resource",
                        "namespace": "default",
                        "annotations": {}
                    }
                }
            },
            "parameters": {
                "annotation": "elastisys.io/ok-to-delete",
                "kinds": prevented_kinds
            }
        }
    }
}

test_delete_resource_with_annotation_is_allowed {
    every i in prevented_kinds {
        count(violation) == 0 with input as {
            "review": {
                "operation": "DELETE",
                "object": {
                    "apiVersion": "*",
                    "kind": i,
                    "metadata": {
                        "name": "test-resource",
                        "namespace": "default",
                        "annotations": {
                            "elastisys.io/ok-to-delete": "anything"
                        }
                    }
                }
            },
            "parameters": {
                "annotation": "elastisys.io/ok-to-delete",
                "kinds": prevented_kinds
            }
        }
    }
}

test_non_delete_operation_without_annotation_is_allowed {
    every i in prevented_kinds {
        count(violation) == 0 with input as {
            "review": {
                "operation": "UPDATE",
                "object": {
                    "apiVersion": "*",
                    "kind": i,
                    "metadata": {
                        "name": "test-resource",
                        "namespace": "default",
                        "annotations": {}
                    }
                }
            },
            "parameters": {
                "annotation": "elastisys.io/ok-to-delete",
                "kinds": prevented_kinds
            }
        }
    }
}

test_without_annotations_field {
    count(violation) == 1 with input as {
        "review": {
            "operation": "DELETE",
            "object": {
                "apiVersion": "*",
                "kind": "Cluster",
                "metadata": {
                    "name": "test-resource",
                    "namespace": "default"
                }
            }
        },
        "parameters": {
            "annotation": "elastisys.io/ok-to-delete",
            "kinds": prevented_kinds
        }
    }
}

test_delete_other_kind_is_allowed {
    count(violation) == 0 with input as {
        "review": {
            "operation": "DELETE",
            "object": {
                "apiVersion": "*",
                "kind": "Pod",
                "metadata": {
                    "name": "test-pod",
                    "namespace": "default",
                }
            }
        },
        "parameters": {
            "annotation": "elastisys.io/ok-to-delete",
            "kinds": prevented_kinds
        }
    }
}

test_some_other_annotation {
    count(violation) == 0 with input as {
        "review": {
            "operation": "DELETE",
            "object": {
                "apiVersion": "*",
                "kind": "Cluster",
                "metadata": {
                    "name": "test-resource",
                    "namespace": "default",
                    "annotations": {
                        "elastisys.io/something-else": "test"
                    }
                }
            }
        },
        "parameters": {
            "annotation": "elastisys.io/something-else",
            "kinds": prevented_kinds
        }
    }
}

test_bad_annotation {
    count(violation) == 1 with input as {
        "review": {
            "operation": "DELETE",
            "object": {
                "apiVersion": "*",
                "kind": "Cluster",
                "metadata": {
                    "name": "test-resource",
                    "namespace": "default",
                    "annotations": {
                        "elastisys.io/bad-input": "test"
                    }
                }
            }
        },
        "parameters": {
            "annotation": "elastisys.io/something-else",
            "kinds": prevented_kinds
        }
    }
}
