The `elasticsearch-exporter` chart has been replaced with `prometheus-elasticsearch-exporter`. When upgrading, you must uninstall the old chart before applying the new one.

```
# Delete old release
./bin/ck8s ops helm sc uninstall elasticsearch-exporter -n elastic-system

# Install new release
./bin/ck8s ops helmfile sc -l app=prometheus-elasticsearch-exporter -i apply
```
