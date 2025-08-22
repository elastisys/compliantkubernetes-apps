local dashboards = (
  import 'mixin.libsonnet'
).grafanaDashboards;

local replaceContainerExpr(expr) =
  std.strReplace(expr, 'container="cert-manager"', 'container="cert-manager-controller"');

local removeExportedNamespaceExpr(expr) =
  local tmp = std.strReplace(expr, ', "exported_namespace"', '');
  std.strReplace(tmp, ', exported_namespace', '');

local removeExportedNamespaceObj(obj) =
  local tmp = std.objectRemoveKey(obj, "exported_namespace");
  local tmp2 = std.objectRemoveKey(tmp, "exported_namespace 1");
  std.objectRemoveKey(tmp2, "exported_namespace 2");

local updateTargets(targets) =
  std.map(
    function(target)
      if std.objectHas(target, "expr") then
        target + { expr: removeExportedNamespaceExpr(replaceContainerExpr(target.expr)) }
      else
        target,
    targets
  );

local updateTransformations(transformations) =
  std.map(
    function(transformation)
      if transformation.id == "organize" then
        transformation + { options: transformation.options + {
            excludeByName: removeExportedNamespaceObj(transformation.options.excludeByName),
            indexByName: removeExportedNamespaceObj(transformation.options.indexByName),
            renameByName: removeExportedNamespaceObj(transformation.options.renameByName)
          }}
      else
        transformation,
    transformations
  );

local updatePanels(panels) =
  local tmp_panels = std.map(
    function(panel)
      if std.objectHas(panel, "targets") then
        panel + { targets: updateTargets(panel.targets) }
      else
        panel,
    panels
  );
  std.map(
    function(panel)
      if std.objectHas(panel, "transformations") then
        panel + { transformations: updateTransformations(panel.transformations) }
      else
        panel,
    tmp_panels
  );

{
  [std.strReplace(name,'.json','-dashboard.json')]:
    dashboards[name] + {
      timezone: "" ,
      panels: updatePanels(dashboards[name].panels)
    }
  for name in std.objectFields(dashboards)
}
