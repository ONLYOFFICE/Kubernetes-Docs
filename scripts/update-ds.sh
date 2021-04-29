#!/bin/bash
DOCUMENTSERVER_VERSION=""

if [ "$1" == "" ]; then
  echo "Basic parameters are missing."
  exit 1
else
  DOCUMENTSERVER_VERSION=$1
fi

init_prepare4update_job(){
  kubectl get job | grep -iq prepare4update
  if [ $? -eq 0 ]; then
    echo A Job named prepare4update exists. Exit
    exit 1
  else
    wget https://raw.githubusercontent.com/ONLYOFFICE/server/master/schema/postgresql/removetbl.sql
    kubectl create configmap remove-db-scripts --from-file=./removetbl.sql
    kubectl apply -f ./configmaps/update-ds.yaml
  fi
}

create_prepare4update_job(){
  kubectl apply -f ./jobs/prepare4update.yaml
  sleep 5
  PODNAME="$(kubectl get pod | grep -i prepare4update | awk '{print $1}')"
}

check_prepare4update_pod_status(){
  while true; do
      STATUS="$(kubectl get pod "${PODNAME}" |  awk '{print $3}' | sed -n '$p')"
      case $STATUS in
          Error)
            echo "error"
            break
          ;;

          Completed)
            echo "completed"
            break
          ;;

          *)
            sleep 5
          ;;
      esac
  done
}

delete_prepare4update_job(){
  echo -e "\e[0;32m Status of the prepare4update POD: $POD_STATUS. The Job will be deleted \e[0m"
  kubectl delete job prepare4update
}

update_images(){
  kubectl set image deployment/spellchecker \
    spellchecker=onlyoffice/docs-spellchecker-de:${DOCUMENTSERVER_VERSION}
  kubectl set image deployment/converter \
    converter=onlyoffice/docs-converter-de:${DOCUMENTSERVER_VERSION}
  kubectl set image deployment/docservice \
    docservice=onlyoffice/docs-docservice-de:${DOCUMENTSERVER_VERSION} \
    proxy=onlyoffice/docs-proxy-de:${DOCUMENTSERVER_VERSION}
}

print_error_message(){
  echo -e "\e[0;31m Status of the prepare4update POD: $POD_STATUS \e[0m"
  echo -e "\e[0;31m The Job will not be deleted automatically. Further actions to manage the Job must be performed manually. \e[0m"
}

init_prepare4update_job
create_prepare4update_job

echo "Getting the prepare4update POD status..."
POD_STATUS=$(check_prepare4update_pod_status)
if [[ "$POD_STATUS" == "error" ]]; then
  print_error_message
elif [[ "$POD_STATUS" == "completed" ]]; then
  delete_prepare4update_job
  update_images
  echo -e "\e[0;32m The Job update was completed successfully. Wait until all containers with the new version of the images have the READY status. \e[0m"
fi
exit
