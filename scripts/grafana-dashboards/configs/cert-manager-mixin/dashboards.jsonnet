local dashboards = (
  import 'mixin.libsonnet'
).grafanaDashboards;

local replaceContainerExpr(expr) =
  std.strReplace(expr, 'container="cert-manager"', 'container="cert-manager-controller"');

local updateTargets(targets) =
  std.map(
    function(target)
      if std.objectHas(target, "expr") then
        target + { expr: replaceContainerExpr(target.expr) }
      else
        target,
    targets
  );

local updatePanels(panels) =
  std.map(
    function(panel)
      if std.objectHas(panel, "targets") then
        panel + { targets: updateTargets(panel.targets) }
      else
        panel,
    panels
  );

{
  [std.strReplace(name,'.json','-dashboard.json')]:
    dashboards[name] + {
      timezone: "" ,
      panels: updatePanels(dashboards[name].panels)
    }
  for name in std.objectFields(dashboards)
}
