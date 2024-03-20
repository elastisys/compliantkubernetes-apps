local dashboards = (
  import 'mixin.libsonnet'
).grafanaDashboards;

{
  [std.strReplace(name,'.json','-dashboard.json')]: dashboards[name] + { timezone: "" }
  for name in std.objectFields(dashboards)
}
