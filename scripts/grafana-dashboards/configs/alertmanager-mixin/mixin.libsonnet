local alertmanager = import "../../alertmanager-mixin/vendor/alertmanager-mixin/mixin.libsonnet";

// Source: https://github.com/prometheus/alertmanager/blob/main/doc/alertmanager-mixin/config.libsonnet
alertmanager {
  _config+:: {
  },
}
