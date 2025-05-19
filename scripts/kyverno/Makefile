all: test.crt

install: test.crt test.key
	@cp -v $^ ~/.config/notation/localkeys/

%.key:
	openssl genrsa -out $@ 2048

%.crt: %.key %.cnf
	openssl req -new -x509 -key $(firstword $^) -config $(lastword $^) -out $@

.PHONY: all install
