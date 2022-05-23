#!/bin/bash
DOCUMENTSERVER_VERSION=""
PRODUCT_NAME="onlyoffice"
PRODUCT_EDITION="de"
NAMESPACE="default"

if [ "$1" == "" ]; then
  echo "Basic parameters are missing."
  exit 1
fi

while [ "$1" != "" ]; do
  case $1 in
    -pn | --product_name )
       if [ "$2" != "" ]; then
         PRODUCT_NAME=$2
         shift
       fi
    ;;
    -pe | --product_edition )
       if [ "$2" != "" ]; then
         PRODUCT_EDITION=$2
         shift
       fi
    ;;
    -dv | --documentserver_version )
       if [ "$2" != "" ]; then
         DOCUMENTSERVER_VERSION=$2
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

if [ "$DOCUMENTSERVER_VERSION" == "" ]; then
  echo -e "\e[0;31m The DOCUMENT SERVER version cannot be empty \e[0m"
  exit 1
fi

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
    wget https://raw.githubusercontent.com/ONLYOFFICE/Kubernetes-Docs/master/jobs/prepare-ds.yaml
    wget https://raw.githubusercontent.com/ONLYOFFICE/Kubernetes-Docs/master/templates/configmaps/stop-ds.yaml
    kubectl apply -f stop-ds.yaml -n "${NAMESPACE}"
  fi
}

create_prepare_ds_job(){
  export PRODUCT_NAME="${PRODUCT_NAME}"
  export DB_PASSWORD="${DB_PASSWORD}"
  export PVC_NAME="${PVC_NAME}"
  envsubst < prepare-ds.yaml | kubectl apply -f - -n "${NAMESPACE}"
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

update_images(){
  PRODUCT_NAME=$(echo "${PRODUCT_NAME}" | sed 's/-//g')
  kubectl set image deployment/converter \
    converter=${PRODUCT_NAME}/docs-converter-${PRODUCT_EDITION}:${DOCUMENTSERVER_VERSION} -n "${NAMESPACE}"
  kubectl set image deployment/docservice \
    docservice=${PRODUCT_NAME}/docs-docservice-${PRODUCT_EDITION}:${DOCUMENTSERVER_VERSION} \
    proxy=${PRODUCT_NAME}/docs-proxy-${PRODUCT_EDITION}:${DOCUMENTSERVER_VERSION} -n "${NAMESPACE}"
}

print_error_message(){
  echo -e "\e[0;31m Status of the prepare-ds POD: $POD_STATUS \e[0m"
  echo -e "\e[0;31m The Job will not be deleted automatically. Further actions to manage the Job must be performed manually. \e[0m"
}

init_prepare_ds_job
create_prepare_ds_job

echo "Getting the prepare_ds POD status..."
POD_STATUS=$(check_prepare_ds_pod_status)
if [[ "$POD_STATUS" == "error" ]]; then
  print_error_message
else
  delete_prepare_ds_job
  update_images
  echo -e "\e[0;32m The Job update was completed successfully. Wait until all containers with the new version of the images have the READY status. \e[0m"
fi
exit
