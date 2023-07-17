### Release notes

### Added

- Added support for Swift in rclone-sync.
  - It is now possible to specify type (S3/Swift) per bucket.
- Support for nftables backend in calico-accountant via config option `calicoAccountant.backend: nftables`

### Changed

- Increased window for `FrequentPacketsDroppedFromWorkload` and `FrequentPacketsDroppedToWorkload` alerts
  - To make it less sensitive to semi-consistent blocked network traffic.
- Changed location for some dockerfiles to `/images`
- Changed image location for some images from `elastisys/` to `ghcr.io/elastisys/`
- Added secret as a volumetype for osdprepare jobs
- The `score.sh` script now presents results in either structured yaml or machine readable csv

### Fixed

- The Ingress test script to work with proxy-protocol, when used

### Updated

- Upgraded Grafana chart version to `6.57.4` and app version to `9.5.5`
- Upgraded backup-postgres image from ubuntu `18.04` to `22.04` and chart version to `1.3.0`
- Upgraded calico-accountant image from golang `1.11.5` to `1.15.15`
- Upgraded curl-jq:ubuntu image from ubuntu `20.04` to `rolling` and changed chart version to `1.0.0`
- Upgraded compliantkubernetes-apps-log-manager image to a later `ubuntu:rolling` and chart version to `0.2.0`
- Upgraded rclone-sync image app version from `v1.57.0` to `v1.63.0` chart version from `1.3.0` to `1.63.0`
- Upgraded s3-exporter image app version from `0.4.0` to `0.5.0` chart version from `v0.4.0` to `0.5.0`
- Upgraded kured image app version from `v1.12.1` to `v1.13.1` chart version from `4.4.1` to `4.5.1`

### Removed
