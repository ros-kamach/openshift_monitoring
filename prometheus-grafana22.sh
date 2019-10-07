#!/bin/bash

LOGIN=system:admin
SERVER_IP=$(minishift ip)
namespace="openshift-metrics"
datasource_name="prometheus"
sa_reader="prometheus"
grafana_yaml="cluster_recources/grafana.yaml"
prometheus_yaml="cluster_recources/prometheus.yaml"
protocol="https://"
node_exporter_file="grafana_dashboards/node-exporter-dashboard.json"
cluster_monitoring_for_kubernetes="grafana_dashboards/kubernetes-cluster-monitoring.json"

#LOGIN
eval $(minishift oc-env)
oc login -u $LOGIN > /dev/null

if [ "$1" == "apply" ]
    then

        #Prometheus
        oc process -f ${prometheus_yaml} -p NAMESPACE=$namespace | oc apply -f -
        oc adm policy add-scc-to-user -z prometheus-node-exporter -n $namespace hostaccess
        oc annotate ns $namespace openshift.io/node-selector= --overwrite
        oc rollout status deployment/prometheus -n ${namespace}

        #Install Grafana
        oc process -f ${grafana_yaml} -p NAMESPACE=$namespace | oc apply -f -
        oc rollout status deployment/grafana -n ${namespace}
        oc adm policy add-role-to-user view -z grafana -n ${namespace}

        # # setup grafana data source
        grafana_host="${protocol}$( oc get route grafana -n ${namespace}  -o jsonpath='{.spec.host}' )"
        prometheus_host="${protocol}$( oc get route prometheus -n "${namespace}" -o jsonpath='{.spec.host}' )"

###
payload="$( mktemp )"
cat <<EOF >"${payload}"
{
"name": "${datasource_name}",
"type": "prometheus",
"typeLogoUrl": "",
"access": "proxy",
"url": "${prometheus_host}",
"basicAuth": false,
"withCredentials": false,
"jsonData": {
    "tlsSkipVerify":true,
    "httpHeaderName1":"Authorization"
},
"secureJsonData": {
    "httpHeaderValue1":"Bearer $( oc sa get-token "${sa_reader}" -n "${namespace}" )"
}
}
EOF
###
        # create datasource
        curl --insecure -H "Content-Type: application/json" -u admin:admin "${grafana_host}/api/datasources" -X POST -d "@${payload}"

        # create node exporter dashboard
        curl --insecure -H "Content-Type: application/json" -u admin:admin "${grafana_host}/api/dashboards/db" -X POST -d "@./${node_exporter_file}"
        # Cluster Monitoring for Kubernetes
        curl --insecure -H "Content-Type: application/json" -u admin:admin "${grafana_host}/api/dashboards/db" -X POST -d "@./${cluster_monitoring_for_kubernetes}"
    else
        #Install Grafana
        oc process -f "${grafana_yaml}" -p NAMESPACE=$namespace |oc delete -f -

        #Prometheus
        oc process -f "${prometheus_yaml=}" -p NAMESPACE=$namespace |oc delete -f -
fi