DOCKER=docker

help: README.md
	@cat README.md

keys: keys-cosign keys-notation install-notation

keys-cosign: cosign-a.pub cosign-c.pub
keys-notation: notation-a.crt notation-c.crt install-notation

keys.yaml: notation-a.crt notation-a.key notation-c.crt notation-c.key
	yq --input-format csv --output-format yaml > $@ <<EOF
	name,keyPath,certPath
	notation-a,${HOME}/.config/notation/localkeys/notation-a.key,${HOME}/.config/notation/localkeys/notation-a.crt
	notation-b,${HOME}/.config/notation/localkeys/notation-b.key,${HOME}/.config/notation/localkeys/notation-b.crt
	EOF

install-notation: keys.yaml
	@cp --no-clobber --update --verbose $^ ~/.config/notation/localkeys/
	yq --inplace '.keys += load("keys.yaml")' ~/.config/notation/signingkeys.json

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

VARIANTS=a c

build: $(patsubst %,image-cosign-%,$(VARIANTS)) $(patsubst %,image-notation-%,$(VARIANTS))

sign: sign-cosign sign-notation
sign-cosign: $(patsubst %,signed-cosign-%,$(VARIANTS))
sign-notation: $(patsubst %,signed-notation-%,$(VARIANTS))

image-%:
	$(DOCKER) build -f Containerfile --build-arg VARIANT=$* -t ghcr.io/elastisys/kyverno-test-image:$*
	$(DOCKER) push ghcr.io/elastisys/kyverno-test-image:$*
	@touch $@

signed-cosign-%: image-cosign-% keys-cosign
	@echo Press Enter to enter a blank password for the test keys
	for key in $(subst -, ,$*); do
	cosign sign --key cosign-$$key.key --tlog-upload=false ghcr.io/elastisys/kyverno-test-image:cosign-$*
	done
	@touch $@

signed-notation-%: image-notation-% keys-notation
	for key in $(subst -, ,$*); do
	notation sign -k notation-$$key ghcr.io/elastisys/kyverno-test-image:notation-$*
	done
	@touch $@

.PHONY: help keys keys-cosign keys-notation install-notation build sign sign-notation sign-cosign

.PRECIOUS: $(patsubst %,image-cosign-%,$(VARIANTS)) $(patsubst %,image-notation-%,$(VARIANTS))

.ONESHELL:
