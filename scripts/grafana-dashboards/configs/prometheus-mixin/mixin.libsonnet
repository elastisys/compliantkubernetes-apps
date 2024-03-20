local prometheus = import "../../prometheus-mixin/vendor/prometheus-mixin/mixin.libsonnet";

// Source: https://github.com/prometheus/prometheus/blob/main/documentation/prometheus-mixin/config.libsonnet
prometheus {
  _config+:: {
    prometheusSelector: 'job="kube-prometheus-stack-prometheus"',
    grafanaPrometheus: {
      prefix: 'Prometheus / ',
      tags: ['prometheus-mixin'],
      refresh: '30s',
    },
  },
}
