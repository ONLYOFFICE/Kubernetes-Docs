#!/bin/bash

PRODUCT_NAME="onlyoffice"
NAMESPACE="default"

while [ "$1" != "" ]; do
  case $1 in
    -pn | --product_name )
       if [ "$2" != "" ]; then
         PRODUCT_NAME=$2
         shift
       fi
    ;;
    -ns | --namespace )
       if [ "$2" != "" ]; then
         NAMESPACE=$2
         shift
       fi
    ;;
  esac
  shift
done

POD_ALL_DS_NAME="$(kubectl get pod -n "${NAMESPACE}" | grep -i docservice | awk '{print $1}')"
declare -a POD_DS_NAME=($POD_ALL_DS_NAME)
DB_PASSWORD="$(kubectl exec ${POD_DS_NAME[0]} -c docservice -n "${NAMESPACE}" -- sh -c 'echo $DB_PWD')"
PVC_NAME="$(kubectl get pod ${POD_DS_NAME[0]} -n "${NAMESPACE}" -o jsonpath='{.spec.volumes[?(@.name=="ds-files")].persistentVolumeClaim.claimName}')"

init_prepare_ds_job(){
  kubectl get job -n "${NAMESPACE}" | grep -iq prepare-ds
  if [ $? -eq 0 ]; then
    echo A Job named prepare-ds exists. Exit
    exit 1
  else
    kubectl apply -f ./templates/configmaps/stop-ds.yaml -n "${NAMESPACE}"
  fi
}

create_prepare_ds_job(){
  export PRODUCT_NAME="${PRODUCT_NAME}"
  export DB_PASSWORD="${DB_PASSWORD}"
  export PVC_NAME="${PVC_NAME}"
  envsubst < ./jobs/prepare-ds.yaml | kubectl apply -f - -n "${NAMESPACE}"
  sleep 5
  PODNAME="$(kubectl get pod -n "${NAMESPACE}" | grep -i prepare-ds | awk '{print $1}')"
}

check_prepare_ds_pod_status(){
  while true; do
      STATUS="$(kubectl get pod "${PODNAME}" -n "${NAMESPACE}" |  awk '{print $3}' | sed -n '$p')"
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

delete_prepare_ds_job(){
  echo -e "\e[0;32m Status of the prepare-ds POD: $POD_STATUS. The Job will be deleted \e[0m"
  kubectl delete job prepare-ds -n "${NAMESPACE}"
}

print_error_message(){
  echo -e "\e[0;31m Status of the prepare-ds POD: $POD_STATUS \e[0m"
  echo -e "\e[0;31m The Job will not be deleted automatically. Further actions to manage the Job must be performed manually. \e[0m"
}

init_prepare_ds_job
create_prepare_ds_job

echo "Getting the prepare-ds POD status..."
POD_STATUS=$(check_prepare_ds_pod_status)
if [[ "$POD_STATUS" == "error" ]]; then
  print_error_message
else
  delete_prepare_ds_job
  echo -e "\e[0;32m The Job shutdown was completed successfully.\e[0m"
fi
exit
