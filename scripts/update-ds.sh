#!/bin/bash
DOCUMENTSERVER_VERSION=""
LOGOUT_STR="work done"

if [ "$1" == "" ]; then
  echo "Basic parameters are missing."
  exit 1
else
  DOCUMENTSERVER_VERSION=$1
fi

prepare_for_update(){
  kubectl get job | grep -iq prepare4update
  if [ $? -eq 0 ]; then
    echo A Job named prepareupdate exists. Exit
    exit 1
  else
    wget https://raw.githubusercontent.com/ONLYOFFICE/server/master/schema/postgresql/removetbl.sql
    kubectl create configmap remove-db-scripts --from-file=./removetbl.sql
    kubectl apply -f ./configmaps/update-ds.yaml
  fi
}

create_job(){
  kubectl apply -f ./jobs/prepare4update.yaml
  sleep 5
  PODNAME="$(kubectl get pod | grep -i prepare4update | awk '{print $1}')"
}

error_in_job(){
  echo -e "\e[0;31m Now the Pod operation log will be displayed. \e[0m"
  echo -e "\e[0;31m The Job will not be deleted automatically. Further actions to manage the Job must be performed manually. \e[0m"
  sleep 9
  kubectl logs "${PODNAME}"
}

delete_job(){
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

check_status(){
  while true; do
  	  STATUS="$(kubectl get pod "${PODNAME}" |  awk '{print $3}' | sed -n '$p')"
      case $STATUS in
          Error)
            echo -e "\e[0;31m Status of the prepare4update POD: $STATUS \e[0m"
            error_in_job
            exit 1
          ;;

          Completed)
            echo Status of the prepare4update POD: $STATUS
            LOGOUT="$(kubectl logs "${PODNAME}" | sed -n '$p')"
            if [ "${LOGOUT}" == "$LOGOUT_STR" ]; then
              delete_job
              update_images
              echo -e "\e[0;32m The Job update was completed successfully. Wait until all containers with the new version of the images have the READY status. \e[0m"
              exit 0
            else
              echo -e "\e[0;31m The result of the script from Job is different from the expected one. \e[0m"
              error_in_job
              exit 1
            fi
          ;;

          *)
            echo Status of the prepare4update POD: $STATUS. Wait
            sleep 5
          ;;
      esac
  done
}
prepare_for_update
create_job
check_status
