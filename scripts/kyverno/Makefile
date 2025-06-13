DOCKER=docker

help: README.md
	@cat README.md

keys: keys-cosign keys-notation

keys-cosign: cosign-a.pub cosign-b.pub cosign-c.pub
keys-notation: notation-a.crt notation-b.crt notation-c.crt

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

VARIANTS=a b a-b a-c c

build: $(patsubst %,image-cosign-%,$(VARIANTS)) $(patsubst %,image-notation-%,$(VARIANTS))

sign: $(patsubst %,signed-cosign-%,$(VARIANTS)) $(patsubst %,signed-notation-%,$(VARIANTS))

image-%:
	$(DOCKER) build -f Containerfile --build-arg VARIANT=$* -t ghcr.io/elastisys/kyverno-test-image:$*
	$(DOCKER) push ghcr.io/elastisys/kyverno-test-image:$*
	@touch $@

signed-cosign-%: image-% keys-cosign
	@echo Press Enter to enter a blank password for the test keys
	for key in $(subst -, ,$*); do
	cosign sign --key cosign-$$key.key --tlog-upload=false ghcr.io/elastisys/kyverno-test-image:$*
	done
	@touch $@

signed-notation-%: image-% all-notation
	for key in $(subst -, ,$*); do
	notation sign -k $$key ghcr.io/elastisys/kyverno-test-image:$*
	done
	@touch $@

.PHONY: help keys keys-cosign keys-notation install-notation build sign

.ONESHELL:
