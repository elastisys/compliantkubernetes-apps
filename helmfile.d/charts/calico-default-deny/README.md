# calico-default-deny

This helm chart deploys `calico-default-deny`, a global network policy that denies all traffic in a cluster by default.

Currently, usage of this chart requires that the user adds several `additionalEgressPolicies` and `additionalIngressPolicies` in order for the cluster to function correctly.
