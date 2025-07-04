FROM python:3.13.5-slim

RUN pip3 install boto3
RUN groupadd python
RUN useradd -g python -d /home/python python
RUN mkdir -p /home/python
RUN chown python:python /home/python
USER python
WORKDIR /home/python

ENTRYPOINT ["/usr/local/bin/python3"]
