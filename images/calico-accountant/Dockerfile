# Update Alpine base system without recompiling calico-accountant
# docker build -f Dockerfile.updatebase -t ghcr.io/elastisys/calico-accountant:0.1.6-ck8s${N++}
ARG N=2
FROM ghcr.io/elastisys/calico-accountant:0.1.6-ck8s${N} as previous

FROM alpine:3.20
WORKDIR /root/
RUN apk add --no-cache iptables ca-certificates
COPY --from=previous /calico-accountant /calico-accountant
ENTRYPOINT ["/calico-accountant"]
