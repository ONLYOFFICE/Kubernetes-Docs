#!/usr/bin/env bash

# Scripts for deploys and check Kuberneted-Docs helm chart

set -e

while [ "$1" != "" ]; do
	case $1 in

		-tb | --target-branch )
                        if [ "$2" != "" ]; then
                                TARGET_BRANCH=$2
                                shift
                        fi
                ;;
		
	esac
	shift
done

K8S_STORAGE_CLASS="standard"
NFS_PERSISTANCE_SIZE="10Gi"
LITMUS_VERSION="1.13.8"

WORK_DIR=$(pwd)

# Create log file for debug
touch ./log.txt

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
           echo "${COLOR_RED} Something goes wrong. k8s is not ready ${COLOR_RESET}"
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
                                                                           {{ range .status.conditions }}
									   {{ if (or (and (eq .type "PodScheduled")
                                                                           (eq .status "False")) (and (eq .type "Ready") 
									   (eq .status "False"))) }}
                                                                           {{ $item.metadata.name}} {{ end }}{{ end }}{{ end }}')

            ## Get pods logs
            if [[ -n ${PODS} ]]; then
	         echo ${PODS}
                 echo "${COLOR_RED}⚠ ⚠ ⚠  Attention: looks like some pods is not running. Get logs${COLOR_RESET}"
                 for p in ${PODS}; do
                    echo "${COLOR_BLUE} 🔨⎈ Get ${p} logs${COLOR_RESET}"
                    kubectl logs ${p}
                 done
            else 
	         echo "${COLOR_BLUE} 🔨⎈ All pods is ready!${COLOR_RESET}"
            fi
}

function k8s_deploy_deps() {
            echo "${COLOR_BLUE}🔨⎈ Add depends helm repos...${COLOR_RESET}"
            # Add dependency helm charts
	    helm repo add kubemonkey https://asobti.github.io/kube-monkey/charts/repo
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
		kubectl get pods
     }

function k8s_ct_install() {
	    local EXIT_CODE=0
	    
            echo "${COLOR_YELLOW}⚠ Attention: Start ct install test..${COLOR_RESET}"
            ct install --chart-dirs . --charts . --helm-extra-set-args "--set=docservice.livenessProbe.periodSeconds=1 \
	                                                                --set=docservice.livenessProbe.failureThreshold=1 \
									--set=docservice.livenessProbe.timeoutSeconds=2 \
									--set=docservice.resources.requests.memory="256Mi" \
									--set=docservice.resources.requests.cpu="100m" \
									--set=docservice.resources.limits.memory="2000Mi" \
									--set=docservice.resources.limits.cpu="1" \
									--set=proxy.livenessProbe.periodSeconds=1 \
	                                                                --set=proxy.livenessProbe.failureThreshold=1 \
									--set=proxy.livenessProbe.timeoutSeconds=2 \
									--set=proxy.resources.requests.memory="256Mi" \
									--set=proxy.resources.requests.cpu="100m" \
									--set=proxy.resources.limits.memory="2000Mi" \
									--set=proxy.resources.limits.cpu="1" \
									--wait" \
									--skip-clean-up --namespace default || EXIT_CODE=$?
            if [[ "${EXIT_CODE}" == 0 ]]; then
	       local CT_STATUS="success"
               # Get release name
               RELEASE_NAME=$(helm list | grep docs | awk '{print $1}')

	       # Expose docservice for tests
	       kubectl apply -f ./sources/litmus/docs-node.yaml
	       
	         echo
                 echo "${COLOR_GREEN}👌👌👌⎈ Helm install/test/upgrade successfull finished${COLOR_RESET}"
                 echo
	         echo "${COLOR_BLUE}🔨⎈ Get test logs...${COLOR_RESET}"
                 echo
	       
	       kubectl logs -f test-ds --namespace=default
	       k8s_get_info
            else 
	       local CT_STATUS="failed"
	       
	          echo
                  echo "${COLOR_RED}🔥 Helm install\tests\upgrade failed. Get test logs and exit with ${EXIT_CODE}${COLOR_RESET}"
                  echo
	       
	       kubectl logs -f test-ds --namespace=default
	       k8s_pods_logs || true
	       k8s_get_info
               exit ${EXIT_CODE}
            fi

}

function k8s_litmus_install () {
            echo "${COLOR_BLUE}🔨⎈ Install Litmus Chaos...${COLOR_RESET}"
            kubectl apply -f https://litmuschaos.github.io/litmus/litmus-operator-v${LITMUS_VERSION}.yaml
            echo    
            echo "${COLOR_BLUE}🔨⎈ Litmus was deployed with helm. Namespace litmus is created. Wait for ready status...${COLOR_RESET}"
            echo
	    local READY_LITMUS_PODS=""
	    
	    while [ "${READY_LITMUS_PODS}" == "" ]; do
	        echo "${COLOR_YELLOW}Litmus is not ready yet, please wait... ${COLOR_RESET}"
                READY_LITMUS_PODS=$(kubectl get pods -n litmus | grep Running | awk '{ print $3 }')            
                sleep 5
            done
	    
            if [ -n "${READY_LITMUS_PODS}" ]; then
                 echo "${COLOR_GREEN}☑ OK:Litmus is ready ${COLOR_RESET}"
            fi
	    
            kubectl get pods --namespace litmus
	    
	    echo "${COLOR_BLUE}🔨⎈ Install litmus experiments...${COLORE_RESET}"
	    #kubectl apply -f https://hub.litmuschaos.io/api/chaos/1.13.7?file=charts/generic/experiments.yaml -n default
            tar -zxvf <(curl -sL https://github.com/litmuschaos/chaos-charts/archive/3.0.0.tar.gz)
	    find chaos-charts-3.0.0 -name experiments.yaml | grep kubernetes | xargs kubectl apply -n default -f
}

function k8s_docs_status() {	    	    
            if   [ "${1}" == "--get" ]; then
                echo "${COLOR_YELLOW}Message from docs_status function:${COLOR_RESET} Start to get status docservice"
                bash ./sources/litmus/docs-status.sh > /dev/null 2>&1 &
                docs_statusPID=$!
		echo "${COLOR_YELLOW}Message from docs_status function:${COLOR_RESET} docs_status script PID is: ${docs_statusPID}"
            elif [ "${1}" == "--stop" ]; then
	          if ps | grep "${docs_statusPID}"; then
                     echo "${COLOR_YELLOW}Message from docs_status function:${COLOR_RESET} Process is running now. Kill docs-status script with PID: ${docs_statusPID}"
                     kill ${docs_statusPID}
		     docs_status_passed+=("${2}")
		  else
		     echo "${COLOR_RED}Message from docs_status function:${COLOR_RESET} Process with PID ${docs_statusPID} did not found. looks like docs_status did not get 200 code"
		     docs_status_failed+=("${2}")
		  fi
            fi
}

function k8s_litmus_test() {
            # Declare litmus variables
            local litmus_path="./sources/litmus"   
	    local litmus_rbac_path="${litmus_path}/rbac"
	    local litmus_ex_path="${litmus_path}/experiments"
	    
	    local litmus_ex_array=($(ls ${litmus_ex_path} | shuf ))
            local litmus_rbac_array=($(ls ${litmus_rbac_path}))
	    
	    local litmus_ex_name=(
			  "docs-chaos-pod-delete"
			  "docs-chaos-pod-cpu-hog"
			  "docs-chaos-pod-memory-hog"
			  "docs-chaos-pod-network-latency"
			  "docs-chaos-container-kill"
			  "docs-chaos-pod-network-loss"
		          "docs-chaos-pod-network-duplication")
			  
            # Prepare ex manifests for tests on converter deployment too
	    # Uncomment if need tests on converter deployment too

	    #for ex in "${litmus_ex_array[@]:0:3}"; do
	    #       sed -i 's|app=docservice|app=converter|' ${litmus_ex_path}/${ex}
            #done
	    
	    # Apply all litmus rbac
	    for rbac in ${litmus_rbac_array[@]}; do
	        echo "${COLOR_BLUE}Apply ${rbac}${COLOR_RESET}"
	        kubectl apply -f ${litmus_rbac_path}/${rbac}
		sleep 4
	    done
	    
	    echo 
	    echo "${COLOR_BLUE}🔨⎈ All rbac for litmus was applied${COLOR_RESET}"
	    echo
	    	    
            # Start litmus chaos tests
            for ex in ${litmus_ex_name[@]}; do
	         
		 echo
	         echo "${COLOR_BLUE}🔨⎈ Start test: ${ex}${COLOR_RESET}"
	         echo

		 # Start to get docs_status
		 k8s_docs_status --get
		 
		 # Apply litmus chaos test manifest
		 kubectl apply -f ${litmus_ex_path}/${ex}.yaml

		 # Get cluster info
		 kubectl get pods -n default

		 # Wait for Litmus chaos will be injected 
		 sleep 160
		 
		 for i in {1..40}; do	
		      local PHASE="$(kubectl describe chaosresult ${ex} -n default | grep Phase | awk '{print $2}' || true )"
		      local VERDICT="$(kubectl describe chaosresult ${ex} -n default | grep Verdict | awk '{print $2}' || true )"
                      if [ "${PHASE}" == "Running" ] || [ "${VERDICT}" == "Awaited" ]; then
                          echo "${COLOR_BLUE}${i}. Test ${ex} is in progress, please wait...${COLOR_RESET}"
                          sleep 5
                      else
		          if [ "${PHASE}" == "Completed" ] && [ "${VERDICT}" != "Awaited" ]; then
		             echo "${COLOR_BLUE}Test ${ex} is completed${COLOR_RESET}"
		  	  fi
		          break
                      fi
                 done
		 
		 local GENERAL_VERDICT="$(kubectl describe chaosresult ${ex} -n default | grep Verdict | awk '{print $2}' || true )"
		 
		 if [ "${GENERAL_VERDICT}" == "Pass" ]; then 
		      echo "${COLOR_GREEN}☑ OK: Test ${ex} successfully passed${COLOR_RESET}"
		      litmus_passed+=("${ex}")
		 elif [ "${GENERAL_VERDICT}" != "Pass" ]; then
		      echo "${COLOR_RED}FAILED: Test ${ex} is failed${COLOR_RESET}"
	              litmus_failed+=("${ex}")
		 fi
		 
		 sleep 10
		 echo
                 echo "${COLOR_BLUE}🔨⎈ Get ${ex} result${COLOR_RESET}"
		 echo
		 
		 # Check test result
		 kubectl describe chaosresult ${ex} -n default

                 # Cleanup all litmus chaosengines
		 kubectl delete chaosresult ${ex} -n default
		 kubectl delete chaosengine --all -n default
		 
		 now=$(date)
		 k8s_docs_status --stop ${ex}
		 echo "${COLOR_BLUE} TEST WAS ENDED AT ${now}${COLOR_RESET}"
		 # Wait before new test is started
		 sleep 30
            done
            
	    kubectl get pods --namespace default
	    
	    # Test results
	    if [ -n "${docs_status_passed}" ]; then
	         for v in ${docs_status_passed[@]}; do
		   echo "${COLOR_YELLOW}⚠ DOCS STATUS RESULT${COLOR_RESET}: docs_status all time get 200 from docservice pod on litmus test: ${v}"
		 done
	    fi

	    if [ -n "${docs_status_failed}" ]; then
	         for v in ${docs_status_failed[@]}; do
		   echo "${COLOR_RED}⚠ DOCS STATUS RESULT${COLOR_RESET}: docs_status did not get 200 from docservice pod on litmus test: ${v} ${COLOR_RESET}"
		 done
	    fi

            if [ -n "${litmus_passed}" ]; then
	         for v in ${litmus_passed[@]}; do
		   echo "${COLOR_GREEN}☑ OK: litmus test ${v} successfully Passed${COLOR_RESET}"
		 done
		 k8s_helm_test
            fi	 
	    
	    if [ -n "${litmus_failed}" ]; then
	         for v in ${litmus_failed[@]}; do
	           echo "${COLOR_RED}⚠ FAILED: litmus test ${v} has no Passed verdict${COLOR_RESET}"
		 done
		 k8s_helm_test
	    fi
	    
	    if [ -n "${litmus_failed}" ] || [ -n "${docs_status_failed}" ]; then
	          echo "${COLOR_RED} ⚠ ⚠ ATTENTION: Some tests if failed. Please check logs ${COLOR_RESET}"
		  exit 1
	    fi

}

function k8s_helm_install() {
            echo "${COLOR_BLUE}🔨⎈ Deploy docs in k8s...${COLOR_RESET}"
	    local EXIT_CODE=0
            helm install ${RELEASE_NAME:="docs"} . --wait || EXIT_CODE=$?
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
            helm test ${RELEASE_NAME} --namespace=default 
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
	    helm upgrade ${RELEASE_NAME} --wait || EXIT_CODE=$?
	    if [[ $? == 0 ]]; then
	       echo "${COLOR_GREEN} 👌👌👌⎈ Helm upgrade success! ${COLOR_RESET}"
	       k8s_get_info
	    else 
	       echo "${COLOR_RED} Helm upgrade FAILED. ${COLOR_RESET}"
	       exit ${EXIT_CODE}
	    fi
}

function k8s_helm_test_only() {
            # Run only helm install/test/upgrade 
	    # This function will be runed on every created PR   
            k8s_ct_install
}

function k8s_all_tests() {
            # Run all availiable tests for k8s-Docs helm chart
            # This function will be runed only if target branch is master
            k8s_litmus_install
            k8s_ct_install
            k8s_litmus_test
}

function main () {
   common::get_colors
   k8s_get_info
   k8s_w8_workers
   k8s_deploy_deps
   k8s_wait_deps
   if [ "${TARGET_BRANCH}" == "master" ] || [ "${TARGET_BRANCH}" == "main" ]; then
      k8s_all_tests
   else
      echo "${COLOR_YELLOW}ATTENTION: Target branch is not master, run helm install/upgrade/test only${COLOR_RESET}"
      k8s_helm_test_only
   fi
 }

main
