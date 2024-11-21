# Adding Self Managed Cluster Resources

To add a new Self Managed service, do the following:

1. Create a [Helmfile values file](../helmfile.d/values/user-crds/rbac/generator/) with any RBAC required by the services
1. Add the values file to the values file list for `dev-rbac-crds` chart in the [`rbac.yaml` stack](../helmfile.d/stacks/rbac.yaml)
1. Add the group name and names of CRDs that are needed by the service as [gatkeeper constraints under `allowedCRDs`](../helmfile.d/values/user-crds/gatekeeper/user-crds.yaml.gotmpl)
1. Add the necessary [`user` config](../config/wc-config.yaml) to enable the service and update the [schema](../config/schemas/) accordingly
