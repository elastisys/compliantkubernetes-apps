local thanos = import "../../thanos-mixin/vendor/mixin/mixin.libsonnet";

// Source: https://github.com/thanos-io/thanos/blob/main/mixin/config.libsonnet
thanos {
  query+:: {
    selector: 'job=~".*thanos-query-query.*"',
  },
  queryFrontend+:: {
    selector: 'job=~".*thanos-query-query-frontend.*"',
  },
  store+:: {
    selector: 'job=~".*thanos-receiver-store.*"',
  },
  receive+:: {
    selector: 'job=~".*thanos-receiver-receive.*"',
  },
  rule+:: {
    selector: 'job=~".*thanos-receiver-rule.*"',
  },
  compact+:: {
    selector: 'job=~".*thanos-receiver-compact.*"',
  },
  sidecar+:: {
    selector: 'job=~".*thanos-receiver-sidecar.*"',
  },
  bucketReplicate+:: {
    selector: 'job=~".*thanos-receiver-bucket-replicate.*"',
  },
  dashboard+:: {
    timezone: '',
  },
}
