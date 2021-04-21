### Changed

- Only install rbac for user alertmanager if it's enabled.
- Harbor have been updated to v2.2.1.

### Fixed

- When using harbor together with rook there is a potential bug that appears if the database pod is killed and restarted on a new node. This is fixed by upgrading the Harbor helm chart to version 1.6.1.

