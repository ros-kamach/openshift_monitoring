# Prometheus and Grafana for OpenShift

This repository contains components for running either an operational Prometheus and Grafana setup for your OpenShift cluster. 

This Implimentation based on from preconfigurated components in 
<img src="https://i1.wp.com/blog.openshift.com/wp-content/uploads/redhatopenshift.png?w=1376&ssl=1" alt="Thunder" width="20%"/> **"[openshift](https://github.com/ros-kamach/openshift.git)"**

To deploy, run:

syntax:
```
$ bash <*.sh> <project name for monitoring> <apply or delete> 
```
example:
```
$ bash prometheus-grafana.sh openshift-metrics apply
```
![alt text](https://github.com/ros-kamach/openshift_monitoring/raw/master/4.png)
![alt text](https://github.com/ros-kamach/openshift_monitoring/raw/master/3.png)
![alt text](https://github.com/ros-kamach/openshift_monitoring/raw/master/2.png)
![alt text](https://github.com/ros-kamach/openshift_monitoring/raw/master/1.png)
