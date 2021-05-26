# ONLYOFFICE Docs for Kubernetes

This repository contains a set of files to deploy ONLYOFFICE Docs into a Kubernetes cluster or OpenShift cluster.

## Contents
* [Introduction](#introduction)
* [Deploy prerequisites](#deploy-prerequisites)
    - [Add Helm repositories](#1-add-helm-repositories)
    - [Install Persistent Storage](#2-install-persistent-storage)
    - [Deploy RabbitMQ](#3-deploy-rabbitmq)
    - [Deploy Redis](#4-deploy-redis)
    - [Deploy PostgreSQL](#5-deploy-postgresql)
    - [Deploy StatsD exporter](#6-deploy-statsd-exporter)
        + [Add Helm repositories](#61-add-helm-repositories)
        + [Installing StatsD exporter](#62-installing-statsd-exporter)
* [Deploy ONLYOFFICE Docs](#deploy-onlyoffice-docs)
    - [Deploy the ONLYOFFICE Docs license](#1-deploy-the-onlyoffice-docs-license)
    - [Deploy the ONLYOFFICE Docs parameters](#2-deploy-the-onlyoffice-docs-parameters)
    - [Deploy DocumentServer](#3-deploy-documentserver)
    - [Deploy the DocumentServer Example (optional)](#4-deploy-the-documentserver-example-optional)
    - [Expose DocumentServer](#5-expose-documentserver)
        + [Expose DocumentServer via Service (HTTP Only)](#51-expose-documentserver-via-service-http-only)
        + [Expose DocumentServer via Ingress](#52-expose-documentserver-via-ingress)
            1. [Installing the Kubernetes Nginx Ingress Controller](#521-installing-the-kubernetes-nginx-ingress-controller)
            2. [Expose DocumentServer via HTTP](#522-expose-documentserver-via-http)
            3. [Expose DocumentServer via HTTPS](#523-expose-documentserver-via-https)
    - [Update ONLYOFFICE Docs](#6-update-onlyoffice-docs)
        + [Manual update](#61-manual-update)
            1. [Preparing for update](#611-preparing-for-update)
            2. [Update the DocumentServer images](#612-update-the-documentserver-images)
        + [Automated update](#62-automated-update)
* [Using Prometheus to collect metrics with visualization in Grafana (optional)](#using-prometheus-to-collect-metrics-with-visualization-in-grafana-optional)
    - [Deploy Prometheus](#1-deploy-prometheus)
        + [Add Helm repositories](#11-add-helm-repositories)
        + [Installing Prometheus](#12-installing-prometheus)
    - [Deploy Grafana](#2-deploy-grafana)
        + [Preparing for deploy](#21-preparing-for-deploy)
        + [Deploy Grafana without installing ready-made dashboards](#22-deploy-grafana-without-installing-ready-made-dashboards)
        + [Deploy Grafana with the installation of ready-made dashboards](#23-deploy-grafana-with-the-installation-of-ready-made-dashboards)
    - [Expose Grafana via Ingress](#3-expose-grafana-via-ingress)
        + [Expose Grafana via HTTP](#31-expose-grafana-via-http)
        + [Expose Grafana via HTTPS](#32-expose-grafana-via-https)
    - [View gathered metrics in Grafana](#4-view-gathered-metrics-in-grafana)

## Introduction

- You must have a Kubernetes or OpenShift cluster installed. Please, checkout [the reference](https://kubernetes.io/docs/setup/) to set up Kubernetes. Please, checkout [the reference](https://docs.openshift.com/container-platform/4.7/installing/index.html) to setup OpenShift.
- You should also have a local configured copy of `kubectl`. See [this](https://kubernetes.io/docs/tasks/tools/install-kubectl/) guide how to install and configure `kubectl`.
- You should install Helm v3. Please follow the instruction [here](https://helm.sh/docs/intro/install/) to install it.
- If you use OpenShift, you can use both `oc` and `kubectl` to manage deploy. It is also assumed that the user from whom the installation is performed has the role of the cluster admin. See [this](https://docs.openshift.com/container-platform/4.7/authentication/using-rbac.html) guide to add the necessary roles to the user.

## Deploy prerequisites

### 1. Add Helm repositories

```bash
$ helm repo add bitnami https://charts.bitnami.com/bitnami
$ helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
$ helm repo add stable https://charts.helm.sh/stable
$ helm repo update
```

### 2. Install Persistent Storage

Install NFS Server Provisioner

Note: When installing NFS Server Provisioner, Storage Classes - `NFS` is created. When installing to an OpenShift cluster, the user must have a role that allows you to create Storage Classes in the cluster. Read more [here](https://docs.openshift.com/container-platform/4.7/storage/dynamic-provisioning.html)

Note: When installing to an OpenShift cluster, run the following command `oc adm policy add-scc-to-group anyuid system:authenticated` to be able to run Images with any UID.

```bash
$ helm install nfs-server stable/nfs-server-provisioner \
  --set persistence.enabled=true \
  --set persistence.storageClass=PERSISTENT_STORAGE_CLASS \
  --set persistence.size=PERSISTENT_SIZE
```

- `PERSISTENT_STORAGE_CLASS` is a Persistent Storage Class available in your Kubernetes cluster.

  Persistent Storage Classes for different providers:
  - Amazon EKS: `gp2`
  - Digital Ocean: `do-block-storage`
  - IBM Cloud: Default `ibmc-file-bronze`. [More storage classes](https://cloud.ibm.com/docs/containers?topic=containers-file_storage)
  - Yandex Cloud: `yc-network-hdd` or `yc-network-ssd`. [More details](https://cloud.yandex.ru/docs/managed-kubernetes/operations/volumes/manage-storage-class)
  - minikube: `standard`

- `PERSISTENT_SIZE` is the total size of all Persistent Storages for the nfs Persistent Storage Class. You can express the size as a plain integer with one of these suffixes: `T`, `G`, `M`, `Ti`, `Gi`, `Mi`. For example: `8Gi`.

See more details about installing NFS Server Provisioner via Helm [here](https://github.com/helm/charts/tree/master/stable/nfs-server-provisioner#nfs-server-provisioner).

Create a Persistent Volume Claim

```bash
$ kubectl apply -f ./pvc/ds-files.yaml
```

Note: The default `nfs` Persistent Volume Claim is 8Gi. You can change it in the `./pvc/ds-files.yaml` file in the `spec.resources.requests.storage` section. It should be less than `PERSISTENT_SIZE` at least by about 5%. It's recommended to use 8Gi or more for persistent storage for every 100 active users of ONLYOFFICE Docs.

Verify the `ds-files` status

```bash
$ kubectl get pvc ds-files
```

Output:

```
NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
ds-files   Bound    pvc-XXXXXXXX-XXXXXXXXX-XXXX-XXXXXXXXXXXX   8Gi        RWX            nfs            1m
```

### 3. Deploy RabbitMQ

To install RabbitMQ to your cluster, run the following command:

```bash
$ helm install rabbitmq bitnami/rabbitmq \
  --set metrics.enabled=false
```

Note: Set the `metrics.enabled=true` to enable exposing RabbitMQ metrics to be gathered by Prometheus.

See more details about installing RabbitMQ via Helm [here](https://github.com/bitnami/charts/tree/master/bitnami/rabbitmq#rabbitmq).

### 4. Deploy Redis

To install Redis to your cluster, run the following command:

```bash
$ helm install redis bitnami/redis \
  --set architecture=standalone \
  --set auth.enabled=false \
  --set image.tag=5.0.7-debian-10-r51 \
  --set metrics.enabled=false
```

Note: Set the `metrics.enabled=true` to enable exposing Redis metrics to be gathered by Prometheus.

See more details about installing Redis via Helm [here](https://github.com/bitnami/charts/tree/master/bitnami/redis).

### 5. Deploy PostgreSQL

Download the ONLYOFFICE Docs database scheme:

```bash
wget https://raw.githubusercontent.com/ONLYOFFICE/server/master/schema/postgresql/createdb.sql
```

Create a configmap from it:

```bash
$ kubectl create configmap init-db-scripts \
  --from-file=./createdb.sql
```

To install PostgreSQL to your cluster, run the following command:

```
$ helm install postgresql bitnami/postgresql \
  --set initdbScriptsConfigMap=init-db-scripts \
  --set postgresqlDatabase=postgres \
  --set persistence.size=PERSISTENT_SIZE \
  --set metrics.enabled=false
```

Here `PERSISTENT_SIZE` is a size for the PostgreSQL persistent volume. For example: `8Gi`.

It's recommended to use at least 2Gi of persistent storage for every 100 active users of ONLYOFFICE Docs.

Note: Set the `metrics.enabled=true` to enable exposing PostgreSQL metrics to be gathered by Prometheus.

See more details about installing PostgreSQL via Helm [here](https://github.com/bitnami/charts/tree/master/bitnami/postgresql#postgresql).

### 6. Deploy StatsD exporter
*This step is optional. You can skip step [#6](#6-deploy-statsd-exporter) at all if you don't want to run StatsD exporter*

#### 6.1 Add Helm repositories

```bash
$ helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
$ helm repo update
```

#### 6.2 Installing StatsD exporter

To install StatsD exporter to your cluster, run the following command:
```
$ helm install statsd-exporter prometheus-community/prometheus-statsd-exporter \
  --set statsd.udpPort=8125 \
  --set statsd.tcpPort=8126 \
  --set statsd.eventFlushInterval=30000ms
```

Allow the StatsD metrics in ONLYOFFICE Docs:

Set the `data.METRICS_ENABLED` field in the ./configmaps/documentserver.yaml file to the `"true"` value

## Deploy ONLYOFFICE Docs

### 1. Deploy the ONLYOFFICE Docs license

- If you have a valid ONLYOFFICE Docs license, create a secret `license` from the file.

    ```bash
    $ kubectl create secret generic license \
      --from-file=./license.lic
    ```

    Note: The source license file name should be 'license.lic' because this name would be used as a field in the created secret.

- If you have no ONLYOFFICE Docs license, create an empty secret `license` with the following command:

    ```bash
    $ kubectl create secret generic license
    ```

### 2. Deploy the ONLYOFFICE Docs parameters

Deploy the DocumentServer configmap:

```bash
$ kubectl apply -f ./configmaps/documentserver.yaml
```

Create the `jwt` secret with JWT parameters

```bash
$ kubectl create secret generic jwt \
  --from-literal=JWT_ENABLED=true \
  --from-literal=JWT_SECRET=MYSECRET
```

`MYSECRET` is the secret key to validate the JSON Web Token in the request to the ONLYOFFICE Docs.

### 3. Deploy DocumentServer

Deploy the `spellchecker` deployment:

```bash
$ kubectl apply -f ./deployments/spellchecker.yaml
```

Verify that the `spellchecker` deployment is running the desired number of pods with the following command:

```bash
$ kubectl get deployment spellchecker
```

Output:

```
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
spellchecker   2/2     2            2           1m
```

Deploy the spellchecker service:

```bash
$ kubectl apply -f ./services/spellchecker.yaml
```

Deploy the example service:

```bash
$ kubectl apply -f ./services/example.yaml
```

Deploy docservice:

```bash
$ kubectl apply -f ./services/docservice.yaml
```

Deploy the `docservice` deployment:

```bash
$ kubectl apply -f ./deployments/docservice.yaml
```

Verify that the `docservice` deployment is running the desired number of pods with the following command:

```bash
$ kubectl get deployment docservice
```

Output:

```
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
docservice  2/2     2            2           1m
```

Deploy the `converter` deployment:

```bash
$ kubectl apply -f ./deployments/converter.yaml
```

Verify that the `converter` deployment is running the desired number of pods with the following command:

```bash
$ kubectl get deployment converter
```

Output:

```
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
converter   2/2     2            2           1m
```

The `docservice`, `converter` and `spellchecker` deployments consist of 2 pods each other by default.

To scale the `docservice` deployment, use the following command:

```bash
$ kubectl scale -n default deployment docservice --replicas=POD_COUNT
```

where `POD_COUNT` is a number of the `docservice` pods.

Do the same to scale the `converter` and `spellchecker` deployment:

```bash
$ kubectl scale -n default deployment converter --replicas=POD_COUNT
```

```bash
$ kubectl scale -n default deployment spellchecker --replicas=POD_COUNT
```

### 4. Deploy the DocumentServer Example (optional)

*This step is optional. You can skip step [#4](#4-deploy-the-documentserver-example-optional) at all if you don't want to run the DocumentServer Example*

Deploy the example configmap:

```bash
$ kubectl apply -f ./configmaps/example.yaml
```

Deploy the example pod:

```bash
$ kubectl apply -f ./pods/example.yaml
```

### 5. Expose DocumentServer

#### 5.1 Expose DocumentServer via Service (HTTP Only)
*You should skip step [#5.1](#51-expose-documentserver-via-service-http-only) if you are going to expose DocumentServer via HTTPS*

This type of exposure has the least overheads of performance, it creates a loadbalancer to get access to DocumentServer.
Use this type of exposure if you use external TLS termination, and don't have another WEB application in the k8s cluster.

Deploy the `documentserver` service:

```bash
$ kubectl apply -f ./services/documentserver-lb.yaml
```

Run the following command to get the `documentserver` service IP:

```bash
$ kubectl get service documentserver -o jsonpath="{.status.loadBalancer.ingress[*].ip}"
```

After that, ONLYOFFICE Docs will be available at `http://DOCUMENTSERVER-SERVICE-IP/`.

If the service IP is empty, try getting the `documentserver` service hostname:

```bash
$ kubectl get service documentserver -o jsonpath="{.status.loadBalancer.ingress[*].hostname}"
```

In this case, ONLYOFFICE Docs will be available at `http://DOCUMENTSERVER-SERVICE-HOSTNAME/`.

#### 5.2 Expose DocumentServer via Ingress

#### 5.2.1 Installing the Kubernetes Nginx Ingress Controller

To install the Nginx Ingress Controller to your cluster, run the following command:

```bash
$ helm install nginx-ingress ingress-nginx/ingress-nginx --set controller.publishService.enabled=true,controller.replicaCount=2
```

Note: To install Nginx Ingress with the same parameters and to enable exposing ingress-nginx metrics to be gathered by Prometheus, run the following command:

```bash
$ helm install nginx-ingress -f ./ingresses/ingress_values.yaml ingress-nginx/ingress-nginx
```

See more details about installing Nginx Ingress via Helm [here](https://github.com/kubernetes/ingress-nginx/tree/master/charts/ingress-nginx).

Deploy the `documentserver` service:

```bash
$ kubectl apply -f ./services/documentserver.yaml
```

*Note: In all the steps below concerning Nginx Ingress for Kubernetes versions below 1.19, deploy must be performed from the `./ingresses/before-1.19` directory.
For example: `$ kubectl apply -f ./ingresses/before-1.19/documentserver.yaml`*

#### 5.2.2 Expose DocumentServer via HTTP

*You should skip step [#5.2.2](#522-expose-documentserver-via-http) if you are going to expose DocumentServer via HTTPS*

This type of exposure has more overheads of performance compared with exposure via service, it also creates a loadbalancer to get access to DocumentServer. 
Use this type if you use external TLS termination and when you have several WEB applications in the k8s cluster. You can use the one set of ingress instances and the one loadbalancer for those. It can optimize the entry point performance and reduce your cluster payments, cause providers can charge a fee for each loadbalancer.

Deploy documentserver ingress:

```bash
$ kubectl apply -f ./ingresses/documentserver.yaml
```

Run the following command to get the `documentserver` ingress IP:

```bash
$ kubectl get ingress documentserver -o jsonpath="{.status.loadBalancer.ingress[*].ip}"
```

After that, ONLYOFFICE Docs will be available at `http://DOCUMENTSERVER-INGRESS-IP/`.

If the ingress IP is empty, try getting the `documentserver` ingress hostname:

```bash
$ kubectl get ingress documentserver -o jsonpath="{.status.loadBalancer.ingress[*].hostname}"
```

In this case, ONLYOFFICE Docs will be available at `http://DOCUMENTSERVER-INGRESS-HOSTNAME/`.

#### 5.2.3 Expose DocumentServer via HTTPS

This type of exposure allows you to enable internal TLS termination for DocumentServer.

Create the `tls` secret with an ssl certificate inside.

Put the ssl certificate and the private key into the `tls.crt` and `tls.key` files and then run:

```bash
$ kubectl create secret generic tls \
  --from-file=./tls.crt \
  --from-file=./tls.key
```

Open `./ingresses/documentserver-ssl.yaml` and type your domain name instead of `example.com`

Deploy documentserver ingress

```bash
$ kubectl apply -f ./ingresses/documentserver-ssl.yaml
```

Run the following command to get the `documentserver` ingress IP:

```bash
$ kubectl get ingress documentserver -o jsonpath="{.status.loadBalancer.ingress[*].ip}"
```

If the ingress IP is empty, try getting the `documentserver` ingress hostname:

```bash
$ kubectl get ingress documentserver -o jsonpath="{.status.loadBalancer.ingress[*].hostname}"
```

Associate the `documentserver` ingress IP or hostname with your domain name through your DNS provider.

After that, ONLYOFFICE Docs will be available at `https://your-domain-name/`.

### 6. Update ONLYOFFICE Docs

#### 6.1 Manual update

*You should skip step [#6.1](#61-manual-update) if you want to perform the update using a script*

#### 6.1.1 Preparing for update

The next script creates a job, which shuts down the service, clears the cache files and clears tables in the database.
Download the ONLYOFFICE Docs database script for database cleaning:

```bash
$ wget https://raw.githubusercontent.com/ONLYOFFICE/server/master/schema/postgresql/removetbl.sql
```

Create a configmap from it:

```bash
$ kubectl create configmap remove-db-scripts --from-file=./removetbl.sql
```

Create a configmap containing the update script:

```bash
$ kubectl apply -f ./configmaps/update-ds.yaml
```

Run the job:

```bash
$ kubectl apply -f ./jobs/prepare4update.yaml
```

After successful run, the job automaticly terminates its pod, but you have to clean the job itself manually:

```bash
$ kubectl delete job prepare4update
```

#### 6.1.2 Update the DocumentServer images

Update deployment images:
```
$ kubectl set image deployment/spellchecker \
  spellchecker=onlyoffice/docs-spellchecker-de:DOCUMENTSERVER_VERSION

$ kubectl set image deployment/converter \
  converter=onlyoffice/docs-converter-de:DOCUMENTSERVER_VERSION

$ kubectl set image deployment/docservice \
  docservice=onlyoffice/docs-docservice-de:DOCUMENTSERVER_VERSION \
  proxy=onlyoffice/docs-proxy-de:DOCUMENTSERVER_VERSION
```
`DOCUMENTSERVER_VERSION` is the new version of docker images for ONLYOFFICE Docs.

#### 6.2 Automated update

To perform the update using a script, run the following command:

```bash
$ ./scripts/update-ds.sh [DOCUMENTSERVER_VERSION]
```
`DOCUMENTSERVER_VERSION` is the new version of docker images for ONLYOFFICE Docs.

## Using Prometheus to collect metrics with visualization in Grafana (optional)
*This step is optional. You can skip this section if you don't want to install Prometheus and Grafana*

### 1. Deploy Prometheus

#### 1.1 Add Helm repositories

```bash
$ helm repo add kube-state-metrics https://kubernetes.github.io/kube-state-metrics
$ helm repo update
```

#### 1.2 Installing Prometheus

To install Prometheus to your cluster, run the following command:

```bash
$ helm install prometheus prometheus-community/prometheus
```

See more details about installing Prometheus via Helm [here](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus).

### 2. Deploy Grafana

#### 2.1 Preparing for deploy

Create the Grafana configmap:

```
$ kubectl apply -f ./configmaps/grafana.yaml
```

Сreate a secret that contains Prometheus as Grafana Data sources:

```
$ kubectl apply -f ./secrets/grafana-datasource.yaml
```

#### 2.2 Deploy Grafana without installing ready-made dashboards

*You should skip step [#2.2](#22-deploy-grafana-without-installing-ready-made-dashboards) if you want to Deploy Grafana with the installation of ready-made dashboards*

To install Grafana to your cluster, run the following command:

```bash
$ helm install grafana bitnami/grafana \
  --set service.port=80 \
  --set config.useGrafanaIniFile=true \
  --set config.grafanaIniConfigMap=grafana-ini \
  --set datasources.secretName=grafana-datasource
```

#### 2.3 Deploy Grafana with the installation of ready-made dashboards

Run the `./metrics/get_dashboard.sh` script, which will download ready-made dashboards in `JSON` format from the Grafana [website](https://grafana.com/grafana/dashboards),
make the necessary edits to them and create a configmap from them. A dashboard will also be added to visualize metrics coming from the DocumentServer (it is assumed that step [#6](#6-deploy-statsd-exporter) has already been completed).

```
$ ./metrics/get_dashboard.sh
```

To install Grafana to your cluster, run the following command:

```bash
$ helm install grafana bitnami/grafana \
  --set service.port=80 \
  --set config.useGrafanaIniFile=true \
  --set config.grafanaIniConfigMap=grafana-ini \
  --set datasources.secretName=grafana-datasource \
  --set dashboardsProvider.enabled=true \
  --set dashboardsConfigMaps[0].configMapName=dashboard-node-exporter \
  --set dashboardsConfigMaps[0].fileName=dashboard-node-exporter.json \
  --set dashboardsConfigMaps[1].configMapName=dashboard-deployment \
  --set dashboardsConfigMaps[1].fileName=dashboard-deployment.json \
  --set dashboardsConfigMaps[2].configMapName=dashboard-redis \
  --set dashboardsConfigMaps[2].fileName=dashboard-redis.json \
  --set dashboardsConfigMaps[3].configMapName=dashboard-rabbitmq \
  --set dashboardsConfigMaps[3].fileName=dashboard-rabbitmq.json \
  --set dashboardsConfigMaps[4].configMapName=dashboard-postgresql \
  --set dashboardsConfigMaps[4].fileName=dashboard-postgresql.json \
  --set dashboardsConfigMaps[5].configMapName=dashboard-nginx-ingress \
  --set dashboardsConfigMaps[5].fileName=dashboard-nginx-ingress.json \
  --set dashboardsConfigMaps[5].configMapName=dashboard-documentserver \
  --set dashboardsConfigMaps[5].fileName=documentserver-statsd-exporter.json
```

After executing this command, the following dashboards will be imported into Grafana:

  - Node Exporter
  - Deployment Statefulset Daemonset
  - Redis Dashboard for Prometheus Redis Exporter
  - RabbitMQ-Overview
  - PostgreSQL Database
  - NGINX Ingress controller
  - DocumentServer

See more details about installing Grafana via Helm [here](https://github.com/bitnami/charts/tree/master/bitnami/grafana).

### 3 Expose Grafana via Ingress

*This step is optional. You can skip step [#3](#3-expose-grafana-via-ingress) if you don't want to use Nginx Ingress to access the Grafana web interface*

Note: It is assumed that step [#5.2.1](#521-installing-the-kubernetes-nginx-ingress-controller) has already been completed.

*Note: In all the steps below concerning Nginx Ingress for kubernetes versions below 1.19, deploy must be performed from the `./ingresses/before-1.19` directory.
For example: `$ kubectl apply -f ./ingresses/before-1.19/grafana.yaml`*

#### 3.1 Expose Grafana via HTTP
*You should skip step [#3.1](#31-expose-grafana-via-http) if you are going to expose Grafana via HTTPS*

Deploy Grafana ingress:

```bash
$ kubectl apply -f ./ingresses/grafana.yaml
```

After that you will have access to Grafana at `http://INGRESS-ADDRESS/grafana/`

#### 3.2 Expose Grafana via HTTPS

Note: It is assumed that step [#5.2.3](#523-expose-documentserver-via-https) has already been completed.

Open `./ingresses/grafana-ssl.yaml` and type your domain name instead of `example.com`.

Deploy Grafana ingress:

```bash
$ kubectl apply -f ./ingresses/grafana-ssl.yaml
```

After that you will have access to Grafana at `https://your-domain-name/grafana/`

### 4. View gathered metrics in Grafana

Go to the address `http(s)://your-domain-name/grafana/`

Login - admin

To get the password, run the following command:
```
$ kubectl get secret grafana-admin --namespace default -o jsonpath="{.data.GF_SECURITY_ADMIN_PASSWORD}" | base64 --decode
```

In the dashboard section, you will see the added dashboards that will display the metrics received from Prometheus.
