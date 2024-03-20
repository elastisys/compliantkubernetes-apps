local kubernetes = import "../../kubernetes-mixin/vendor/kubernetes-mixin/mixin.libsonnet";

// Source: https://github.com/kubernetes-monitoring/kubernetes-mixin/blob/master/config.libsonnet
kubernetes {
  _config+:: {
    // Selectors are inserted between {} in Prometheus queries.
    cadvisorSelector: 'job="kubelet"',
    kubeletSelector: 'job="kubelet"',
    kubeStateMetricsSelector: 'job="kube-state-metrics"',
    nodeExporterSelector: 'job="node-exporter"',
    kubeSchedulerSelector: 'job="kube-scheduler"',
    kubeControllerManagerSelector: 'job="kube-controller-manager"',
    kubeApiserverSelector: 'job="apiserver"',
    kubeProxySelector: 'job="kube-proxy"',
    podLabel: 'pod',
    hostNetworkInterfaceSelector: 'device!~"veth.+"',
    hostMountpointSelector: 'mountpoint="/"',
    windowsExporterSelector: 'job="kubernetes-windows-exporter"',
    containerfsSelector: 'container!=""',
    // Config for the Grafana dashboards in the Kubernetes Mixin
    grafanaK8s: {
      dashboardNamePrefix: 'Kubernetes / ',
      dashboardTags: ['kubernetes-mixin'],

      // For links between grafana dashboards, you need to tell us if your grafana
      // servers under some non-root path.
      linkPrefix: '',

      // The default refresh time for all dashboards, default to 10s
      refresh: '30s',
      minimumTimeInterval: '1m',

      // Timezone for Grafana dashboards:: UTC, browser, ...
      grafanaTimezone: '',
    },

    // Opt-in to multiCluster dashboards by overriding this and the clusterLabel.
    showMultiCluster: true,
    clusterLabel: 'cluster',

    namespaceLabel: 'namespace',

    // Default datasource name
    datasourceName: 'default',
  },
}
