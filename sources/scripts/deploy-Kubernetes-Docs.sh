#!/usr/bin/env bash

# Scripts for deploys and check Kuberneted-Docs helm chart

set -e

K8S_STORAGE_CLASS="standard"
NFS_PERSISTANCE_SIZE="8Gi"
DEPLOY_NAME="documentserver"

export TERM=xterm-256color^M

function common::get_colors() {
    COLOR_BLUE=$'\e[34m'
    COLOR_GREEN=$'\e[32m'
    COLOR_RED=$'\e[31m'
    COLOR_RESET=$'\e[0m'
    COLOR_YELLOW=$'\e[33m'
    export COLOR_BLUE
    export COLOR_GREEN
    export COLOR_RED
    export COLOR_RESET
    export COLOR_YELLOW
}

function k8s_w8_workers() {
         for i in {1..20}; do
            echo "${COLOR_BLUE}🔨⎈ Get k8s workers status ${i}...${COLOR_RESET}"
            local NODES_STATUS=$(kubectl get nodes -o json | jq -r '.items[] | select ( .status.conditions[] | select( .type=="Ready" and .status=="False")) | .metadata.name')
            if [[ -z "${NODES_STATUS}" ]]; then
              echo "${COLOR_GREEN}☑ OK: K8s workers is ready. Continue...${COLOR_RESET}"
              local k8s_workers_ready='true'
              break
            else
              sleep 5
            fi
         done
         if [[ "${k8s_workers_ready}" != 'true' ]]; then
           err "\e[0;31m Something goes wrong. k8s is not ready \e[0m"
           exit 1
         fi
}

function k8s_get_info() {
            echo "${COLOR_BLUE}🔨⎈ Get cluster info...${COLOR_RESET}"
            kubectl get all
            kubectl get ns
            kubectl get sc
            kubectl get nodes
}

function k8s_pods_logs() {
            ## Get not ready pods
            local PODS=$(kubectl get pods --all-namespaces -o go-template='{{ range $item := .items }}
            {{ range .status.conditions }}{{ if (or (and (eq .type "PodScheduled")
            (eq .status "False")) (and (eq .type "Ready") (eq .status "False"))) }}
            {{ $item.metadata.name}} {{ end }}{{ end }}{{ end }}')

            ## Get pods logs
            if [[ -n ${PODS} ]]; then
                 echo "${COLOR_RED}⚠ ⚠ ⚠  Attention: looks like some pods is not running. Get logs${COLOR_RESET}"
                 for p in ${PODS}; do
                    echo "${COLOR_BLUE} 🔨⎈ Get ${p} logs${COLOR_RESET}"
                    kubectl logs ${p}
                 done
            fi
}

function k8s_deploy_deps() {
            echo "${COLOR_BLUE}🔨⎈ Add depends helm repos...${COLOR_RESET}"
            # Add dependency helm charts
            helm repo add bitnami https://charts.bitnami.com/bitnami
            helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
            helm repo add nfs-server-provisioner https://kubernetes-sigs.github.io/nfs-ganesha-server-and-external-provisioner
            helm repo add onlyoffice https://download.onlyoffice.com/charts/stable
            helm repo update
            echo "${COLOR_GREEN}☑ OK: Helm repository was added${COLOR_RESET}" 

            echo "${COLOR_BLUE}🔨⎈ Lets deploy dependency...${COLOR_RESET}"
            # Install nfs server
            helm install nfs-server nfs-server-provisioner/nfs-server-provisioner \
                 --set persistence.enabled=true \
                 --set persistence.storageClass=${K8S_STORAGE_CLASS} \
                 --set persistence.size=${NFS_PERSISTANCE_SIZE} > /dev/null 2>&1
            echo "${COLOR_GREEN}☑ OK: NFS Server was deployed${COLOR_RESET}"

            # Install rabbitmq
            helm install rabbitmq bitnami/rabbitmq \
                 --set metrics.enabled=false > /dev/null 2>&1
            echo "${COLOR_GREEN}☑ OK: Rabbitmq was deployed${COLOR_RESET}"

            # Install redis
            helm install redis bitnami/redis \
                 --set architecture=standalone \
                 --set metrics.enabled=false > /dev/null 2>&1
            echo "${COLOR_GREEN}☑ OK: Redis was deployed${COLOR_RESET}"

            # Install postgresql
            helm install postgresql bitnami/postgresql \
                 --set auth.database=postgres \
                 --set primary.persistence.size=2G \
                 --set metrics.enabled=false > /dev/null 2>&1
            echo "${COLOR_GREEN}☑ OK: Postgresql was deployed${COLOR_RESET}"
     }

function k8s_wait_deps() {
                echo "${COLOR_BLUE}🔨⎈ Wait 2 minutes for k8s-Docs dependencies${COLOR_RESET}"
                sleep 120
     }

function k8s_ct_install() {
	    EXIT_CODE=0
            echo "${COLOR_YELLOW}⚠ Attention: Start ct install test..${COLOR_RESET}"
            ct install --chart-dirs . --charts . --helm-extra-set-args "--set=namespaceOverride=default --wait" || EXIT_CODE=$?
            if [[ "${EXIT_CODE}" == 0 ]]; then
	       local CT_STATUS="success"
	       echo
               echo "${COLOR_GREEN}👌👌👌⎈ Helm install/test/upgrade successfull finished${COLOR_RESET}"
               echo
	       echo "${COLOR_BLUE}🔨⎈ Get test logs...${COLOR_RESET}"
               echo
	       kubectl logs -f test-ds --namespace=default
	       k8s_get_info
	       exit ${EXIT_CODE}
            else 
	       local CT_STATUS="failed"
	       echo
               echo "${COLOR_RED}🔥Tests failed. Get test logs and exit with 1${COLOR_RESET}"
               echo
	       k8s_get_info
               exit ${EXIT_CODE}
            fi
     }

function k8s_deploy_docs() {
            echo "${COLOR_BLUE}🔨⎈ Deploy docs in k8s...${COLOR_RESET}"
	    local EXIT_CODE=0
            helm install ${DEPLOY_NAME} . --set namespaceOverride=default --wait || EXIT_CODE=$?
	    if [[ "${EXIT_CODE}" == 0 ]]; then
	       sleep 60
	       k8s_get_info
	       echo "${COLOR_BLUE} 🔨⎈ Docs successfully deployed. Continue.. Run Helm test.${COLOR_RESET}"
	    else
	       echo "${COLOR_RED}🔥 Docs deploy failed. Exit${COLOR_RESET}"
	       k8s_get_info
	       k8s_pods_logs
	       exit ${EXIT_CODE}
	    fi
     }

function k8s_helm_test() {
            echo "${COLOR_BLUE}🔨⎈ Start helm test..${COLOR_RESET}"
            helm test ${DEPLOY_NAME} --namespace=default
            if [[ $? == 0 ]]; then
               echo "${COLOR_GREEN} 👌👌👌⎈ Helm test success! ${COLOR_RESET}"
	       echo "${COLOR_BLUE} 🔨⎈ Get test logs... ${COLOR_RESET}"
               kubectl logs -f test-ds --namespace=default
	    else
	       echo "${COLOR_RED} Helm test FAILED. ${COLOR_RESET}"
	       exit 1
            fi
     }

function k8s_helm_upgrade() {
            echo "${COLOR_BLUE}🔨⎈ Start helm upgrade..${COLOR_RESET}"
	    local EXIT_CODE=0
	    helm upgrade ${DEPLOY_NAME} . || EXIT_CODE=$?
	    if [[ $? == 0 ]]; then
	       echo "${COLOR_GREEN} 👌👌👌⎈ Helm upgrade success! ${COLOR_RESET}"
	    else
	       echo "${COLOR_RED} Helm upgrade FAILED. ${COLOR_RESET}"
	       exit ${EXIT_CODE}
	    fi
}

function k8s_remove_pods() {
            local RANDOM_PODS=$(echo "$(kubectl -n default get pods -o go-template='{{range $index, $element := .items}}{{range .status.containerStatuses}}{{if .ready}}{{$element.metadata.name}}{{"\n"}}{{end}}{{end}}{{end}}' | uniq | shuf)" )
	    echo
            echo "${COLOR_BLUE}🔨⎈ Try to remove random pods and Helm test again...${COLOR_RESET}"
	    echo

            local pods_array=()
            local pods_array+=(${RANDOM_PODS})
            echo ${pods_array[@]}

            for i in "${pods_array[@]:0:5}"; do
	       kubectl delete pod ${i}
               echo "${COLOR_BLUE}pod ${i} was deleted${COLOR_RESET}"
            done

}

function main () {
   common::get_colors
   k8s_get_info
   k8s_w8_workers
   k8s_deploy_deps
   k8s_wait_deps
   k8s_deploy_docs
   k8s_helm_test
   k8s_helm_upgrade
   k8s_remove_pods
 }

main
