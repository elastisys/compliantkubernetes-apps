# Application developer kube-config for contributors

There can be situations where you as a contributor needs to act as a application developer.
This document describes how to add a service account to act as a application developer for development purposes.

First add a name for the service account in your `wc-config.yaml`

```diff
...
user:
  namespaces:
    - production
+  serviceAccounts:
+    - test
  adminUsers:
    - admin@example.com
...
```

Then run `bin/ck8s kubeconfig dev test`.

This will add a possible context to your `kube_config_wc.yaml`.

To see the new context `kubectl config get-contexts`

```console
CURRENT   NAME         CLUSTER      AUTHINFO           NAMESPACE
          test         foo-wc       test@foo-wc        default
*         foo-wc       foo-wc       admin@foo-wc       default
```

To switch to the new context run the following `kubectl config use-context test`
