FROM ubuntu:rolling as download

# Install dependencies
RUN apt-get update && apt-get install -y curl unzip

# Install rclone
ENV RCLONE_VERSION="v1.63.0"
RUN curl -O https://downloads.rclone.org/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-linux-amd64.zip && \
    unzip rclone-${RCLONE_VERSION}-linux-amd64.zip && \
    cd rclone-*-linux-amd64 && \
    install rclone /usr/bin/rclone

FROM ubuntu:rolling as final

# Install root certificates
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y ca-certificates && \
    apt-get clean -y

# Copy in rclone
COPY --from=download /usr/bin/rclone /usr/bin/rclone

# Create rclone user
RUN apt-get install adduser && \
    adduser --system --home /home/rclone --uid 10000 rclone

# Run as rclone user
USER 10000

ENTRYPOINT ["rclone"]
CMD ["--version"]
