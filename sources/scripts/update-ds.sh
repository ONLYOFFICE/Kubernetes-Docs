#!/bin/bash
DOCUMENTSERVER_VERSION=""
PRODUCT_NAME="onlyoffice"
PRODUCT_REPO=""
PRODUCT_EDITION=""

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
    -pr | --product_repo )
       if [ "$2" != "" ]; then
         PRODUCT_REPO=$2
         shift
       fi
    ;;
    -pe | --product_edition )
       if [ "$2" != "" ]; then
         PRODUCT_EDITION=$2
         shift
       fi
    ;;
    -dv | --document_version )
       if [ "$2" != "" ]; then
         DOCUMENTSERVER_VERSION=$2
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

if [ "$PRODUCT_REPO" == "" ]; then
  PRODUCT_REPO="${PRODUCT_NAME}"
fi

if [ "$PRODUCT_EDITION" != "" ]; then
  PRODUCT_EDITION="-${PRODUCT_EDITION}"
fi

init_prepare4update_job(){
  kubectl get job | grep -iq prepare4update
  if [ $? -eq 0 ]; then
    echo A Job named prepare4update exists. Exit
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

create_prepare4update_job(){
  export PRODUCT_NAME="${PRODUCT_NAME}"
  envsubst < ./jobs/prepare4update.yaml | kubectl apply -f -
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
  kubectl set image deployment/converter \
    converter=${PRODUCT_REPO}/docs-converter${PRODUCT_EDITION}:${DOCUMENTSERVER_VERSION}
  kubectl set image deployment/docservice \
    docservice=${PRODUCT_REPO}/docs-docservice${PRODUCT_EDITION}:${DOCUMENTSERVER_VERSION} \
    proxy=${PRODUCT_REPO}/docs-proxy${PRODUCT_EDITION}:${DOCUMENTSERVER_VERSION}
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
else
  delete_prepare4update_job
  update_images
  echo -e "\e[0;32m The Job update was completed successfully. Wait until all containers with the new version of the images have the READY status. \e[0m"
fi
exit
