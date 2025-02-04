FROM ubuntu:24.04
LABEL org.opencontainers.image.source=https://github.com/elastisys/compliantkubernetes-apps

ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=Etc/UTC

RUN apt-get update && \
    apt-get install -y ca-certificates curl gzip s3cmd zstd && \
    curl -sSL -O https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb && \
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash && \
    dpkg -i packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install azcopy && \
    apt-get clean && \
    rm packages-microsoft-prod.deb && \
    rm -rf /var/lib/apt/lists/*


USER 1000:1000

RUN az extension add --upgrade -n storage-preview
