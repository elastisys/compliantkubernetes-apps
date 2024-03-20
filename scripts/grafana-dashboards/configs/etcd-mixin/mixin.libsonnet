local etcd = import "../../etcd-mixin/vendor/mixin/mixin.libsonnet";

// Source: https://github.com/etcd-io/etcd/blob/main/contrib/mixin/config.libsonnet
etcd {
  _config+: {}
}
