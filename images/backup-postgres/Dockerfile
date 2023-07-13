FROM ubuntu:22.04
RUN apt-get update     \
    && apt-get install --no-install-recommends -y \
        apt-utils \
        apt-transport-https \
        software-properties-common \
        ca-certificates \
        lsb-release \
        tar \
        python3-pip \
        python3-setuptools \
        curl \
        jq \
        gnupg \
    && pip3 install --no-cache-dir awscli --upgrade \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && cat /etc/apt/sources.list.d/pgdg.list \
    && curl --silent https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - \
    && add-apt-repository ppa:rmescandon/yq \
    && apt-get update \
    && apt-get install --no-install-recommends -y  \
        postgresql-client-14  \
        postgresql-client-13  \
        postgresql-client-12  \
        postgresql-client-11  \
        google-cloud-sdk \
        yq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd nonrootuser
RUN useradd -g nonrootuser -d /home/nonrootuser nonrootuser
RUN mkdir -p /home/nonrootuser
RUN chown nonrootuser:nonrootuser /home/nonrootuser
USER nonrootuser
WORKDIR /home/nonrootuser
ENTRYPOINT ["/bin/bash"]
