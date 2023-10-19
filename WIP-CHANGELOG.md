### Release notes

### Added

- Network policies from `rook-ceph-crashcollector`
- The possibility to set a different domain from `baseDomain` for blakcboxExporter probes
- Exposed the option to set `tty` for falco

### Changed

- Log management jobs `successfulJobsHistoryLimit` was decreased to 1 from

### Fixed

- Rclone sync enable Thanos and Harbor destination swift only if `.objectStorage.sync.syncDefaultBuckets = true`
- Rclone sync added `domainName` and `projectDomainName` fields for swift config
- Harbor artifacts alert description
- Alertmanager custom template

### Updated

- Ingress-nginx controller to 1.8.4 and chart to 4.7.3 (HTTP/2 fix for CVE-2023-44487)
    - a limit of no more than 2 * max_concurrent_streams new streams per one event loop iteration was introduced
    - refused streams are now limited to maximum of max_concurrent_streams and 100
