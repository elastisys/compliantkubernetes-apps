### Release notes

### Updated

- Update the Velero plugin for AWS to v1.3.1
- Updated ingress-nginx helm chart to v4.1.3 and ingress-nginx controller image to v1.2.1
   > **Breaking changes**
      - deprecated http2_recv_timeout in favor of client_header_timeout (client-header-timeout);
      - deprecated http2_max_field_size (http2-max-field-size) and http2_max_header_size (http2-max-header-size) in favor of large_client_header_buffers (large-client-header-buffers);
      - deprecated http2_idle_timeout and http2_max_requests (http2-max-requests) in favor of keepalive_timeout (upstream-keepalive-timeout?) and keepalive_requests (upstream-keepalive-requests?) respectively;
      - added an option to jail/chroot the nginx process, inside the controller container, is being introduced;
      - implemented an object deep inspector. The inspection is a walk through of all the spec, checking for possible attempts to escape configs.

### Changed

- Bump falco-exporter chart to v0.8.0.
- Users are now not forced to use proxy for connecting to alertmanager but can use port-forward as well.

### Fixed

- `prometheus-blackbox-exporter's` internal thanos servicemonitor changed name to avoid name collisions.
- dex `topologySpreadConstraints` matchLabel was changed from `app: dex` to `app.kubernetes.io/name: dex` to increase stability of replica placements.
- Fixed issue where user admin groups wasn't added to the user alertmanager rolebinding

### Added

- Add option to encrypt off-site buckets replicated with rclone sync
- Added metrics for field mappings and an alert that will throw an error if the fields get close to the max limit.

### Removed
