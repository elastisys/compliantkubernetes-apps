local dashboards = (
  import 'mixin.libsonnet'
).grafanaDashboards;

{
  ['thanos-' + std.strReplace(name,'.json','-dashboard.json')]: dashboards[name]
  for name in std.objectFields(dashboards)
}
