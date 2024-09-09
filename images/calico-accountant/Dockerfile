# Update Alpine base system without recompiling calico-accountant
# docker build -f Dockerfile.updatebase -t ghcr.io/elastisys/calico-accountant:0.1.6-ck8s${N++}
FROM ghcr.io/elastisys/calico-accountant:0.1.6 as previous

FROM alpine:3.18
WORKDIR /root/
RUN apk --update add iptables
COPY --from=previous /calico-accountant /calico-accountant
