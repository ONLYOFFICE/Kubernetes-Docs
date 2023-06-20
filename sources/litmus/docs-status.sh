#!/usr/bin/env bash

set -e

DOCSERVICE_URL=$(minikube service docs-node --url)
EXIT_CODE=0 
 
while [ "${EXIT_CODE}" == "0" ]; do
     curl --fail -I --retry-all-errors --connect-timeout 5 --max-time 40 --retry 3 --retry-delay 10 --retry-max-time 40 ${DOCSERVICE_URL}/index.html || EXIT_CODE=$? 
     if [ "${EXIT_CODE}" != "0" ]; then
        echo "Process failed. Exit with exit code: ${EXIT_CODE}"
        exit ${EXIT_CODE}
     fi
     sleep 1
done
