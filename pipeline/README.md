# Running Bats tests locally

If you want to run Bats tests locally (instead of in the CI pipeline), execute the following from the project root directory:

```bash
git submodule update --recursive --init # init and update bats helpers

docker build -t ck8s-apps ./pipeline
# FIXME - there is no ./pipeline/sops-pgp-setup.bash anymore (?)
docker run --rm -it -e CK8S_PGP_FP=529D964DE0BBD900C4A395DA09986C297F8B7757 \
    -v "$(pwd):/ck8s-apps:ro" -w /ck8s-apps ck8s-apps \
    bash -c './pipeline/sops-pgp-setup.bash && bats ./pipeline'
```

Some tests might take some time to run, to skip them set the environment variable `CK8S_SKIP_LONG_RUNNING_TESTS`.
