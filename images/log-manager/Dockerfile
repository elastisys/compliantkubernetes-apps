FROM ubuntu:rolling
LABEL org.opencontainers.image.source https://github.com/elastisys/compliantkubernetes-apps

ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=Etc/UTC

RUN apt-get update && \
 apt-get install -y ca-certificates curl gzip s3cmd zstd && \
 curl -sL https://aka.ms/InstallAzureCLIDeb | bash && \
 apt-get clean && \
 rm -rf /var/lib/apt/lists/*

USER 1000:1000

RUN az extension add --upgrade -n storage-preview