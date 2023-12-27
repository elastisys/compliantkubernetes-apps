# tekton-dashboard

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v0.33.0](https://img.shields.io/badge/AppVersion-v0.33.0-informational?style=flat-square)

A Helm chart for Tekton Dashboards

**Homepage:** <https://github.com/tektoncd/dashboard>

## Values

| Key                                            | Type   | Default                                                                                                                          | Description |
|------------------------------------------------|--------|----------------------------------------------------------------------------------------------------------------------------------|-------------|
| dashboardDeployment.container.image.digest     | string | `"sha256:02dd3b2f4aa17038991de5032b6da790080a7e663510da673464bba9c74ef900"`                                                      |             |
| dashboardDeployment.container.image.repository | string | `"gcr.io/tekton-releases/github.com/tektoncd/dashboard/cmd/dashboard"`                                                           |             |
| dashboardDeployment.container.image.tag        | string | `"v0.33.0"`                                                                                                                      |             |
| dashboardDeployment.container.port             | int    | `9097`                                                                                                                           |             |
| dashboardDeployment.replicas                   | int    | `1`                                                                                                                              |             |
| icon                                           | string | `"https://github.com/cdfoundation/artwork/blob/main/tekton/additional-artwork/tekton_dashboard/color/TektonDashboard_color.svg"` |             |
