Example on how to add or update a Chart:

```
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo up
helm fetch falcosecurity/falco --version 1.5.2 --untar
```
