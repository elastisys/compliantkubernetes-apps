### Changed

- Only install rbac for user alertmanager if it's enabled.
- Convert all values to integers for elasticsearch slm cronjob
- The script for generating a user kubeconfig is now `bin/ck8s kubeconfig user` (from `bin/ck8s user-kubeconfig`)

### Added

- Authlog now indexed by elasticsearch
- Added a ClusterRoleBinding for using an OIDC-based cluster admin kubeconfig and a script for generating such a kubeconfig (see `bin/ck8s kubeconfig admin`)
