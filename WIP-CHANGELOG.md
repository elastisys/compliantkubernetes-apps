
### Fixed

- Disabled prometheus rules for the kube-apiserver that lacked metrics and caused the wc-reader to go out of memory when trying to evaluate them
- Fixed opensearch migration script that used an uncompatible argument for curl
