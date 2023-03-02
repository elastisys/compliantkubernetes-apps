FROM ubuntu:20.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    jq \
    curl \
    cron \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -ms /bin/bash jq \
    && adduser jq crontab \
    && chmod u+s /usr/sbin/cron

USER jq

CMD crontab -u jq /scripts/cronjob && cron && tail -f /dev/null
