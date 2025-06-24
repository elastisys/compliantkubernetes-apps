# calico-default-deny

This helm chart deploys `cilium-default-deny`, a clusterwide network policy that denies all traffic in a cluster by default.

Currently, usage of this chart requires that the user adds several `additionalEgressPolicies` and `additionalIngressPolicies` in order for the cluster to function correctly.

See examples in <https://docs.cilium.io/en/stable/security/policy/kubernetes/#example-cnp-ns-boundaries> for configuring additional policies.
