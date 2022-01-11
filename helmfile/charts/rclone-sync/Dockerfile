FROM ubuntu:latest as download

# Install dependencies
RUN apt-get update && apt-get install -y curl unzip

# Install rclone
RUN curl -O https://downloads.rclone.org/rclone-current-linux-amd64.zip && \
    unzip rclone-current-linux-amd64.zip && \
    cd rclone-*-linux-amd64 && \
    install rclone /usr/bin/rclone

FROM ubuntu:latest as final


# Install root certificates
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y ca-certificates && \
    apt-get clean -y

# Copy in rclone
COPY --from=download /usr/bin/rclone /usr/bin/rclone

# Create rclone user
RUN adduser --system --uid 10000 rclone

# Run as rclone user
USER 10000

ENTRYPOINT ["rclone"]
CMD ["--version"]
