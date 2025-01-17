# metrics-server

Parts of the definition is generated from Kubernetes schema types:

```shell
../hack/kube-schema-dereference.bash io.k8s.api.core.v1.ResourceRequirements | \
    yq4 -i '.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties.resources = load("/dev/stdin")' ./apis/definition.yaml

../hack/kube-schema-dereference.bash io.k8s.api.core.v1.Toleration | \
    yq4 -i '.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties.tolerations = load("/dev/stdin")' ./apis/definition.yaml

../hack/kube-schema-dereference.bash io.k8s.api.core.v1.Affinity | \
    yq4 -i '.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties.affinity = load("/dev/stdin")' ./apis/definition.yaml

yq4 --prettyPrint -i 'sort_keys(.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties)'  ./apis/definition.yaml
```
