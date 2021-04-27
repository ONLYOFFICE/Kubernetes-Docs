#!/bin/bash
DOCUMENTSERVER_VERSION=""
LOGOUT_STR="work done"
STATUS_STR="Completed"

if [ "$1" == "" ]; then
  echo "Basic parameters are missing."
  exit 1
else
  DOCUMENTSERVER_VERSION=$1
fi

wget https://raw.githubusercontent.com/ONLYOFFICE/server/master/schema/postgresql/removetbl.sql
kubectl create configmap remove-db-scripts --from-file=./removetbl.sql
kubectl apply -f ./configmaps/update-ds.yaml
kubectl apply -f ./jobs/prepare4update.yaml
sleep 5
PODNAME="$(kubectl get pod | grep -i prepare4update | awk '{print $1}')"

updating(){
  STATUS="$(kubectl get pod "${PODNAME}" |  awk '{print $3}' | sed -n '$p')"
  LOGOUT="$(kubectl logs "${PODNAME}" | sed -n '$p')"
  if [ "${LOGOUT}" == "$LOGOUT_STR" ]; then
    if [ "${STATUS}" == "$STATUS_STR" ]; then
      kubectl delete job prepare4update
      kubectl set image deployment/spellchecker \
        spellchecker=onlyoffice/docs-spellchecker-de:${DOCUMENTSERVER_VERSION}
      kubectl set image deployment/converter \
        converter=onlyoffice/docs-converter-de:${DOCUMENTSERVER_VERSION}
      kubectl set image deployment/docservice \
        docservice=onlyoffice/docs-docservice-de:${DOCUMENTSERVER_VERSION} \
        proxy=onlyoffice/docs-proxy-de:${DOCUMENTSERVER_VERSION}
    else
      echo -e "\e[0;31m The update preparation Job has an incorrect status \e[0m"
      kubectl delete job prepare4update
      exit 1
    fi
  else
    kubectl delete job prepare4update
    echo -e "\e[0;31m The result of the script from Job is different from the expected one \e[0m"
    exit 1
  fi
}

while true; do
    case $STATUS in
        Error)
          echo -e "\e[0;31m The update preparation Job has an incorrect status \e[0m"
          echo $STATUS
          kubectl delete job prepare4update
          exit 1
        ;;

        Completed)
          echo $STATUS
          updating
          echo -e "\e[0;32m The update was completed successfully. Wait until all containers with the new version of the images have the READY status \e[0m"
          exit 0
        ;;

        *)
          echo $STATUS
          sleep 5
          STATUS="$(kubectl get pod "${PODNAME}" |  awk '{print $3}' | sed -n '$p')"
        ;;
    esac
done
