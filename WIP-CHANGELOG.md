### Release notes

### Updated

### Changed

### Fixed

- Fixed broken index per namespace feature for logging. The version of `elasticsearch_dynamic` plugin in Fluentd no longer supports OpenSearch. Now the OpenSearch output plugin is used for the feature thanks to the usage of placeholders.
- Fixed conflicting type `ts` in opensearch, where multiple services log `ts` as different types.
- Fixed conflicting type `@timestamp`, should always be `date` in opensearch.
- Fluentd no longer tails its own container log. Fixes the issue when Fluentd failed to push to OpenSearch and started filling up its logs with `\`. Because recursive logging of its own errors to OpenSearch which kept failing and for each fail adding more `\`.

### Added

### Removed
