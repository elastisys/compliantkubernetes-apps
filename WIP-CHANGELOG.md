### Release notes

- Ck8sdash has been deprecated and will be removed when upgrading.
  Some resources like it's namespace will have to be manually removed.
- Check out the [upgrade guide](migration/v0.9.x-v0.10.x/upgrade-apps.md) for a complete set of instructions needed to upgrade.

### Added

- Several new dashboards for velero, nginx, gatekeeper, uptime of services, and kubernetes status.
- Metric scraping for nginx, gatekeeper, and velero.
- Check for Harbor endpoint in the blackbox exporter.

### Changed

- The falco dashboard has been updated with a new graph, multicluster support, and a link to kibana.
- Changed path that fluentd looks for kubernetes audit logs to include default path for kubespray.

### Fixed

- Fixed issue with adding annotation to bootstrap namespace chart

### Removed

- Ck8sdash.
