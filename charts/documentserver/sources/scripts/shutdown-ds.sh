#!/bin/bash

PRODUCT_NAME="onlyoffice"

while [ "$1" != "" ]; do
  case $1 in
    -pn | --product_name )
       if [ "$2" != "" ]; then
         PRODUCT_NAME=$2
         shift
       fi
    ;;
  esac
  shift
done

init_prepare4shutdown_job(){
  kubectl get job | grep -iq prepare4shutdown
  if [ $? -eq 0 ]; then
    echo A Job named prepare4shutdown exists. Exit
    exit 1
  else
    kubectl delete cm remove-db-scripts init-db-scripts
    wget -O removetbl.sql https://raw.githubusercontent.com/ONLYOFFICE/server/master/schema/postgresql/removetbl.sql
    wget -O createdb.sql https://raw.githubusercontent.com/ONLYOFFICE/server/master/schema/postgresql/createdb.sql
    kubectl create configmap remove-db-scripts --from-file=./removetbl.sql
    kubectl create configmap init-db-scripts --from-file=./createdb.sql
    kubectl apply -f ./sources/stop-ds.yaml
  fi
}

create_prepare4shutdown_job(){
  export PRODUCT_NAME="${PRODUCT_NAME}"
  envsubst < ./jobs/prepare4shutdown.yaml | kubectl apply -f -
  sleep 5
  PODNAME="$(kubectl get pod | grep -i prepare4shutdown | awk '{print $1}')"
}

check_prepare4shutdown_pod_status(){
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

delete_prepare4shutdown_job(){
  echo -e "\e[0;32m Status of the prepare4shutdown POD: $POD_STATUS. The Job will be deleted \e[0m"
  kubectl delete job prepare4shutdown
}

print_error_message(){
  echo -e "\e[0;31m Status of the prepare4shutdown POD: $POD_STATUS \e[0m"
  echo -e "\e[0;31m The Job will not be deleted automatically. Further actions to manage the Job must be performed manually. \e[0m"
}

init_prepare4shutdown_job
create_prepare4shutdown_job

echo "Getting the prepare4shutdown POD status..."
POD_STATUS=$(check_prepare4shutdown_pod_status)
if [[ "$POD_STATUS" == "error" ]]; then
  print_error_message
else
  delete_prepare4shutdown_job
  echo -e "\e[0;32m The Job shutdown was completed successfully.\e[0m"
fi
exit
