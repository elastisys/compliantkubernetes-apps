### Running Bats tests locally

If you want to run Bats tests locally (instead of in the CI pipeline), execute the following from the project root directory:

```bash
docker build -t ck8s-apps ./pipeline
docker run --rm -it -v "$(pwd):/ck8s-apps:ro" -w /ck8s-apps ck8s-apps \
    bash -c './pipeline/sops-pgp-setup.bash && bats ./pipeline'
```

Some tests might take some time to run, to skip them set the environment variable `CK8S_SKIP_LONG_RUNNING_TESTS`.
