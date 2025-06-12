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
	yes "" | cosign generate-key-pair --output-key-prefix cosign-$*

.PHONY: all install-notation
