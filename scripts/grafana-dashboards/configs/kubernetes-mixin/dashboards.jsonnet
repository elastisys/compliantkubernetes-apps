local dashboards = (
  import 'mixin.libsonnet'
).grafanaDashboards;

{
  [std.strReplace(name,'.json','-dashboard.json')]: dashboards[name] +
    (if name == 'k8s-resources-pod.json' then
      {
        "annotations": {
          "list": [
            {
              "builtIn": 1,
              "datasource": {
                "type": "grafana",
                "uid": "-- Grafana --"
              },
              "enable": true,
              "hide": true,
              "iconColor": "rgba(0, 211, 255, 1)",
              "name": "Annotations & Alerts",
              "type": "dashboard"
            },
            {
              "datasource": {
                "type": "prometheus",
                "uid": "${datasource}"
              },
              "enable": true,
              "expr": "changes(kube_pod_container_status_restarts_total{pod=\"$pod\"}[$__interval]) > 0",
              "iconColor": "red",
              "name": "Container restart",
              "step": "",
              "textFormat": "Container \"{{ container }}\" restarted",
              "titleFormat": "Container restarted"
            }
          ]
        },
      }
    else {})
  for name in std.objectFields(dashboards)
}
