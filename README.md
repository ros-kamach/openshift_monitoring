# Prometheus and Grafana for OpenShift

This directory contains example components for running either an operational Prometheus setup for your OpenShift cluster, or deploying a standalone secured Prometheus instance for configurating yourself.

To deploy, run:

syntax:
```
$bash <*.sh> <project name for monitoring> <apply or delete> 
```
example:
```
$ bash prometheus-grafana.sh openshift-metrics apply
```
