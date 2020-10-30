Example deployment for jmx using java agent
===========================================

# Overview
The jmx-example.yaml deploys the erikgunne/rep:testjar docker image, exporting java metrics over port 8080. The program uses java agents to run a jmx exporter. The jmx-service.yaml creates a service for the exposed metrics. The jmx-monitor.yaml creates a service monitor that prometheus scrapes data from.

# User setup
If a user want to export metrics for prometheus to scrape they need to create a service monintor with the lable ```labels: prometheus-operator``` and the name ```name: user-*```
