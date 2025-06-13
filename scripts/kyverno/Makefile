DOCKER=docker

help: README.md
	@cat README.md

all: all-cosign all-notation

all-cosign: cosign-a.pub cosign-b.pub cosign-c.pub
all-notation: notation-a.crt notation-b.crt notation-c.crt

install-notation: notation-a.crt notation-a.key notation-b.crt notation-b.key notation-c.crt notation-c.key
	@cp -v $^ ~/.config/notation/localkeys/

# Notation (regular X.509)
notation-%.key:
	openssl genrsa -out $@ 2048

notation-%.crt: notation-%.key notation-%.cnf
	openssl req -new -x509 -key $(firstword $^) -config $(lastword $^) -out $@

notation-%.cnf: notation.cnf
	KEYNAME=$* envsubst < $^ > $@

# Cosign
cosign-%.pub cosign-%.key:
	@echo Press Enter twice to assign a blank password to the test keys
	cosign generate-key-pair --output-key-prefix cosign-$*

# Test images
# TODO
# for each of cosign and notation
# one image signed by key A for single singner test
# one image signed by key A and key B for multi-singner test
# one image signed by key A and key C for negative multi-signer test
# one image signed by key C for negative tests

build: image-cosign-a image-cosign-a-b image-cosign-a-c image-cosign-c image-notation-a image-notation-a-b image-notation-a-c image-notation-c

sign: signed-cosign-a signed-cosign-a-b signed-cosign-a-c signed-cosign-c signed-notation-a signed-notation-a-b signed-notation-a-c signed-notation-c


image-%:
	$(DOCKER) build -f Containerfile --build-arg VARIANT=$* -t ghcr.io/elastisys/kyverno-test-image:$*
	@echo $(DOCKER) push ghcr.io/elastisys/kyverno-test-image:$*
	@touch $@

signed-cosign-%: image-% all-cosign
	for key in $(subst -, ,$*); do
	echo cosign sign --key $$key --tlog-upload=false ghcr.io/elastisys/kyverno-test-image:$*
	done
	@touch $@

signed-notation-%: image-% all-notation
	for key in $(subst -, ,$*); do
	echo notation sign -k $$key ghcr.io/elastisys/kyverno-test-image:$*
	done
	@touch $@

.PHONY: help all all-cosign all-notation install-notation build sign

.ONESHELL:
