local node = import "../../node-mixin/vendor/node-mixin/mixin.libsonnet";

// Source: https://github.com/prometheus/node_exporter/blob/master/docs/node-mixin/config.libsonnet
node {
  _config+:: {
    showMultiCluster: true,
    clusterLabel: 'cluster',
    dashboardNamePrefix: 'Node Exporter / ',
    dashboardTags: ['node-exporter-mixin'],
  },
}
