### Release notes

### Updated

### Changed

- Set 'continue_if_exception' in curator as to not fail when a snapshot is in progress and it is trying to remove some indices.
- Exposed opensearch-slm-job max request seconds for curl.
- Made opensearch-slm-job more verbose when using curl.
- Added persistence to alertmanager.
- made the [CISO grafana dashboards](https://elastisys.io/compliantkubernetes/ciso-guide/) visible to the end-users


### Fixed

### Added
- Added Prometheus alerts for the 'backup status' and 'daily checks' dashboards. Also, 's3BucketPercentLimit' and 's3BucketSizeQuotaGB' parameters to set what limits the s3 rule including will alert off.

### Removed
