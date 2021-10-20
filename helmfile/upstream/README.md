Example on how to add or update a Chart:

```
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo up
helm fetch falcosecurity/falco --version 1.5.2 --untar
```

# Note

The Starboard Operator currently uses a subchart containing a PSP to allow the Trivy scanners to run and the RBAC to use it. Keep it until it is supported upstream.
