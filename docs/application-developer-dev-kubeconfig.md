# Application developer kube-config for contributors

There can be situations where you as a contributor needs to act as a application developer.
This document describes how to add a service account to act as a application developer for development purposes.

First add a name for the service account in your `wc-config.yaml`

```diff
...
user:
  namespaces:
    - production
+ serviceAccounts:
+   - <svcacc-name>
  adminUsers:
    - admin@example.com
...
```

Next export `$CK8S_CONFIG_PATH` apply to cluster with `./bin/ck8s ops helmfile wc apply`. You should see that the service account has been added to the cluster.

You can then run `./bin/ck8s kubeconfig dev <svcacc-name>`. This will add a possible context to your `kube_config_wc.yaml` located in the `$CK8S_CONFIG_PATH/.state/` folder.

To see the new context run `kubectl config get-contexts`.

```console
CURRENT   NAME           CLUSTER      AUTHINFO              NAMESPACE
          <svcacc-name>  foo-wc       <svcacc-name>@foo-wc  default
*         foo-wc         foo-wc       admin@foo-wc          default
```

To switch to the new context run the following: `kubectl config use-context <svcacc-name>`
