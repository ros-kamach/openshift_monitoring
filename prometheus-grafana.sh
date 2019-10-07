#!/bin/bash

#For Running Script write <*.sh> <jenkins_project> <thunder_proje> <apply or delete>
## exampl # bash project.sh jenkins-ci thunder

#######################################
############## Enviroment #############
#######################################
LIGHT_GREAN='\033[1;32m'
RED='\033[0;31m'
NC='\033[0m'
LOGIN=system:admin
SERVER_IP=$(minishift ip)
namespace="$1"
datasource_name="prometheus"
sa_reader="prometheus"
grafana_yaml="cluster_recources/grafana.yaml"
prometheus_yaml="cluster_recources/prometheus.yaml"
protocol="https://"
node_exporter_file="grafana_dashboards/node-exporter-dashboard.json"
cluster_monitoring_for_kubernetes="grafana_dashboards/kubernetes-cluster-monitoring.json"
#######################################
############## Function: ##############
####### Check for apply/delete ########
#######################################
check_args () {
case $4 in
  (apply|delete) ;; # OK
  (*) printf >&2 "Wrong arg.${2}${4}${3}. Allowed are ${1}apply${3} or ${1}delete${3} \n";
      printf >&2 "!!! \n";
      printf >&2 "syntax: bash <*.sh> <project name for monitoring> <apply or delete> \n";
      printf >&2 "## \n";
      printf >&2 "example: bash prometheus-grafana.sh openshift-metrics apply \n";exit 1;;
esac
}
#######################################
############## Function: ##############
##### Check URI for response 200 ######
#######################################
response_api_check () {
SCRIPT_URI=https://raw.githubusercontent.com/ros-kamach/bash_healthcheck/master/health_check.sh
MAX_RETRIES=20
CHECKING_URL=${1}
echo "Check Connection to Server"
curl -s "${SCRIPT_URI}" | bash -s "${MAX_RETRIES}" "$CHECKING_URL"
echo "200 OK"
}
#######################################
############## Function:  #############
### Function: Approve process Name ####
#######################################
approve_yes_no_other () {
while true; do
        if [ "$2" == "apply" ]
            then
                printf "Checking namespases: $4 for exists\n"
                printf "If it exest script will generate new namespases\n"
                printf "${1}Basic value exist, generated name for Monitoring${3}: ${2}${4}${3}\n"
            else
                printf "${1}Project name for Monitoring${3}: ${2}${4}${3}\n"
        fi
    printf "${2}Continue with names as above:${3}\n"
    read -p "yes(Yn) to process with names as above / no(Nn) to process with basic values  / exit(Xx) to exit script  : " yno
    case $yno in
        [Yy]* ) break;;
        [Nn]* ) MONITORING_PROJECT_NAME=$5;break;;
        [Xx]* ) exit;;
        * ) echo "Please answer yes to use project names:"
            echo "";;
    esac
done
}
#######################################

#LOGIN
eval $(minishift oc-env)
oc login -u $LOGIN > /dev/null

#Check project Names
check_args ${LIGHT_GREAN} ${RED} ${NC} ${2}
if [ "$2" == "apply" ]
    then
        PROCESS=Implementation
        check_project_exist () {
        PROJECT=$1
            if [[ "$( oc get projects | grep -w $PROJECT | awk '{print $1}' )" ]]
                then
                    i=1
                    while [[ "$PROJECT-$i" == "$( oc get projects | grep -w $PROJECT-$i | awk '{print $1}' )" ]] ; do
                    let i++
                    done
                    PROJECT="$PROJECT-$i"
                else
                    PROJECT="$PROJECT"
            fi
        echo $PROJECT
        }

        MONITORING_PROJECT_NAME=$(check_project_exist ${namespace})
        approve_yes_no_other ${LIGHT_GREAN} ${RED} ${NC} ${MONITORING_PROJECT_NAME} $1
        printf "${LIGHT_GREAN}Process with project name for Monitoring${NC}: ${RED}${MONITORING_PROJECT_NAME}${NC}\n"


        #Prometheus
        response_api_check "https://$(minishift ip):8443/oapi/ --insecure"
        printf "${RED}################${NC}\n"
        printf "${LIGHT_GREAN}${PROCESS} Prometheus on cluster${NC}\n"
        oc process -f ${prometheus_yaml} -p NAMESPACE=${MONITORING_PROJECT_NAME} | oc apply -f -
        oc rollout status deployment/prometheus -n ${MONITORING_PROJECT_NAME}
        oc adm policy add-scc-to-user -z prometheus-node-exporter -n ${MONITORING_PROJECT_NAME} hostaccess
        oc annotate ns ${MONITORING_PROJECT_NAME} openshift.io/node-selector= --overwrite
        prometheus_host="${protocol}$( oc get route prometheus -n "${MONITORING_PROJECT_NAME}" -o jsonpath='{.spec.host}' )"
        printf "${RED}################${NC}\n"

        #Install Grafana
        response_api_check "https://$(minishift ip):8443/oapi/ --insecure"
        printf "${RED}################${NC}\n"
        printf "${LIGHT_GREAN}${PROCESS} Grafana on cluster${NC}\n"
        oc process -f ${grafana_yaml} -p NAMESPACE=${MONITORING_PROJECT_NAME} | oc apply -f -
        oc rollout status deployment/grafana -n ${MONITORING_PROJECT_NAME}
        oc adm policy add-role-to-user view -z grafana -n ${MONITORING_PROJECT_NAME}
        grafana_host="${protocol}$( oc get route grafana -n ${MONITORING_PROJECT_NAME}  -o jsonpath='{.spec.host}' )"
        printf "${RED}################${NC}\n"

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
    "httpHeaderValue1":"Bearer $( oc sa get-token "${sa_reader}" -n "${MONITORING_PROJECT_NAME}" )"
}
}
EOF
###
        # # setup grafana data source
        sleep 10
        printf "${LIGHT_GREAN}${PROCESS} Datasource to Grafana${NC}\n"
        curl --insecure -H "Content-Type: application/json" -u admin:admin "${grafana_host}/api/datasources" -X POST -d "@${payload}"
        sleep 10
        printf "\n"
        printf "${RED}################${NC}\n"
        printf "${LIGHT_GREAN}${PROCESS} Grafana Dashboards${NC}\n"
        # create node exporter dashboard
        curl --insecure -H "Content-Type: application/json" -u admin:admin "${grafana_host}/api/dashboards/db" -X POST -d "@./${node_exporter_file}"
        printf "\n"
        printf "${RED}################${NC}\n"
        # Cluster Monitoring for Kubernetes
        curl --insecure -H "Content-Type: application/json" -u admin:admin "${grafana_host}/api/dashboards/db" -X POST -d "@./${cluster_monitoring_for_kubernetes}"
        printf "\n"
        printf "${RED}################${NC}\n"


        printf "${RED}################${NC}\n"
        printf "${LIGHT_GREAN}Grafata wll be accessible via web address at:${NC}\n"
        printf "${LIGHT_GREAN}${protocol}$(oc get route -n ${MONITORING_PROJECT_NAME} | grep grafana | awk '{print $2}')${NC}\n"
        printf "${RED}################${NC}\n"
        printf "${LIGHT_GREAN}Prometheus wll be accessible via web address at:${NC}\n"
        printf "${LIGHT_GREAN}${protocol}$(oc get route -n ${MONITORING_PROJECT_NAME} | grep prometheus | awk '{print $2}')${NC}\n"

    else
        PROCESS=Removing
        check_project_exist () {
        PROJECT=$1
            if [[ "$( oc get projects | grep $PROJECT | head -1 | awk '{print $1}' )" ]]
                then
                    PROJECT="$(oc get projects | grep $PROJECT | head -1 | awk '{print $1}')"
            fi
            echo $PROJECT
        }

        MONITORING_PROJECT_NAME=$(check_project_exist ${namespace})
        approve_yes_no_other ${LIGHT_GREAN} ${RED} ${NC} ${MONITORING_PROJECT_NAME} $1
        printf "${LIGHT_GREAN}Process with project name for Monitoring${NC}: ${RED}${MONITORING_PROJECT_NAME}${NC}\n"

        #Remove Grafana
        printf "${RED}################${NC}\n"
        printf "${LIGHT_GREAN}${PROCESS} Grafana from cluster${NC}\n"
        oc process -f "${grafana_yaml}" -p NAMESPACE=${MONITORING_PROJECT_NAME} |oc delete -f -
        printf "${RED}################${NC}\n"

        #Prometheus
        printf "${RED}################${NC}\n"
        printf "${LIGHT_GREAN}${PROCESS} Prometheus from cluster${NC}\n"
        oc process -f "${prometheus_yaml=}" -p NAMESPACE=${MONITORING_PROJECT_NAME} |oc delete -f -
        printf "${RED}################${NC}\n"

fi