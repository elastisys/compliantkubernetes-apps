FROM ubuntu:rolling
LABEL org.opencontainers.image.source https://github.com/elastisys/compliantkubernetes-apps

ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=Etc/UTC

RUN  apt-get update && \
     apt-get install -y ca-certificates gzip s3cmd zstd  && \
     apt-get clean && \
     rm -rf /var/lib/apt/lists/*

USER 1000:1000
