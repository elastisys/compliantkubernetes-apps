# Kyverno test key generation

This `Makefile` makes it easy to (re)generate the private and public keys for the [Kyverno tests](../../tests/integration/kyverno/).

1. To generate keys, run `make keys`, then `make install-notation` to install the Notary keys where `notation` will find them.
1. To build images, run `make build`, this also uploads them to `ghcr.io`.
1. To sign images, run `make sign`.
