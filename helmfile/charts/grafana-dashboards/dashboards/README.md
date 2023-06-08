# README

The Rook/Ceph dashboards were found through [this page](https://rook.io/docs/rook/v1.6/ceph-monitoring.html).

- Ceph cluster: https://grafana.com/dashboards/2842
- Ceph OSD (Single): https://grafana.com/dashboards/5336
- Ceph pools: https://grafana.com/dashboards/5342

The Thanos dashboards were found through [this page](https://github.com/thanos-io/thanos/tree/main/mixin)

The were built as described but with changing the file `mixins/config.libjsonnet` to match our setup:

```diff
diff --git a/mixin/config.libsonnet b/mixin/config.libsonnet
index 10db073c..c1df45b6 100644
--- a/mixin/config.libsonnet
+++ b/mixin/config.libsonnet
@@ -25,36 +25,36 @@
    // sum by (cluster, namespace, region, zone, job) (rate(thanos_compact_group_compactions_total{cluster=\"$cluster\", namespace=\"$namespace\", region=\"$region\", zone=\"$zone\", job=\"$job\"}[$interval]))
  },
  query+:: {
-    selector: 'job=~".*thanos-query.*"',
+    selector: 'job=~".*thanos-query-query"',
    title: '%(prefix)sQuery' % $.dashboard.prefix,
  },
  queryFrontend+:: {
-    selector: 'job=~".*thanos-query-frontend.*"',
+    selector: 'job=~".*thanos-query-query-frontend.*"',
    title: '%(prefix)sQuery Frontend' % $.dashboard.prefix,
  },
  store+:: {
-    selector: 'job=~".*thanos-store.*"',
+    selector: 'job=~".*thanos-receiver-store.*"',
    title: '%(prefix)sStore' % $.dashboard.prefix,
  },
  receive+:: {
-    selector: 'job=~".*thanos-receive.*"',
+    selector: 'job=~".*thanos-receiver-receive.*"',
    title: '%(prefix)sReceive' % $.dashboard.prefix,
  },
  rule+:: {
-    selector: 'job=~".*thanos-rule.*"',
+    selector: 'job=~".*thanos-receiver-rule.*"',
    title: '%(prefix)sRule' % $.dashboard.prefix,
  },
  compact+:: {
-    selector: 'job=~".*thanos-compact.*"',
+    selector: 'job=~".*thanos-receiver-compact.*"',
    title: '%(prefix)sCompact' % $.dashboard.prefix,
  },
  sidecar+:: {
-    selector: 'job=~".*thanos-sidecar.*"',
+    selector: 'job=~".*thanos-receiver-sidecar.*"',
    thanosPrometheusCommonDimensions: 'namespace, pod',
    title: '%(prefix)sSidecar' % $.dashboard.prefix,
  },
  bucketReplicate+:: {
-    selector: 'job=~".*thanos-bucket-replicate.*"',
+    selector: 'job=~".*thanos-receiver-bucket-replicate.*"',
    title: '%(prefix)sBucketReplicate' % $.dashboard.prefix,
  },
  dashboard+:: {
```
