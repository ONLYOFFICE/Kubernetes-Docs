# ONLYOFFICE DocumentServer for Kubernetes

This repository contains a set of files to deploy ONLYOFFICE DocumentServer into Kubernetes cluster.

## Contents
- [Introduction](#introduction)
- [Deploy prerequisites](#deploy-prerequisites)
  * [1. Add Helm repositories](#1-add-helm-repositories)
  * [2. Install Persistent Storage](#2-install-persistent-storage)
  * [3. Deploy RabbitMQ](#3-deploy-rabbitmq)
  * [4. Deploy Redis](#4-deploy-redis)
  * [5. Deploy PostgreSQL](#5-deploy-postgresql)
  * [6. Deploy StatsD exporter](#6-deploy-statsd-exporter)
    + [6.1 Add Helm repositories](#61-add-helm-repositories)
    + [6.2 Installing StatsD exporter](#62-installing-statsd-exporter)
- [Deploy ONLYOFFICE DocumentServer](#deploy-onlyoffice-documentserver)
  * [1. Deploy the ONLYOFFICE Docs license](#1-deploy-the-onlyoffice-docs-license)
  * [2. Deploy ONLYOFFICE Docs](#2-deploy-onlyoffice-docs)
  * [3. Uninstall ONLYOFFICE Docs](#3-uninstall-onlyoffice-docs)
  * [4. Parameters](#4-parameters)
  * [5. Configuration and installation details](#5-configuration-and-installation-details)
  * [5.1 Example deployment (optional)](#51-example-deployment--optional-)
  * [5.2 StatsD deployment (optional)](#52-statsd-deployment--optional-)
  * [5.3 Expose DocumentServer](#53-expose-documentserver)
    + [5.3.1 Expose DocumentServer via Service (HTTP Only)](#531-expose-documentserver-via-service--http-only-)
    + [5.3.2 Expose DocumentServer via Ingress](#532-expose-documentserver-via-ingress)
    + [5.3.2.1 Installing the Kubernetes Nginx Ingress Controller](#5321-installing-the-kubernetes-nginx-ingress-controller)
    + [5.3.2.2 Expose DocumentServer via HTTP](#5322-expose-documentserver-via-http)
    + [5.3.2.3 Expose DocumentServer via HTTPS](#5323-expose-documentserver-via-https)
  * [6. Update ONLYOFFICE Docs](#6-update-onlyoffice-docs)
    + [6.1 Manual update](#61-manual-update)
    + [6.1.1 Preparing for update](#611-preparing-for-update)
    + [6.1.2 Update the DocumentServer images](#612-update-the-documentserver-images)
    + [6.2 Automated update](#62-automated-update)
- [Using Prometheus to collect metrics with visualization in Grafana (optional)](#using-prometheus-to-collect-metrics-with-visualization-in-grafana--optional-)
  * [1. Deploy Prometheus](#1-deploy-prometheus)
    + [1.1 Add Helm repositories](#11-add-helm-repositories)
    + [1.2 Installing Prometheus](#12-installing-prometheus)
  * [2. Deploy Grafana](#2-deploy-grafana)
    + [2.1 Deploy Grafana without installing ready-made dashboards](#21-deploy-grafana-without-installing-ready-made-dashboards)
    + [2.2 Deploy Grafana with the installation of ready-made dashboards](#22-deploy-grafana-with-the-installation-of-ready-made-dashboards)
  * [3 Expose Grafana via Ingress](#3-expose-grafana-via-ingress)
    + [3.1 Expose Grafana via HTTP](#31-expose-grafana-via-http)
    + [3.2 Expose Grafana via HTTPS](#32-expose-grafana-via-https)
  * [4. View gathered metrics in Grafana](#4-view-gathered-metrics-in-grafana)

## Introduction

- You must have Kubernetes installed. Please, checkout [the reference](https://kubernetes.io/docs/setup/) to setup a Kubernetes.
- You should also have a local configured copy of `kubectl`. See [this](https://kubernetes.io/docs/tasks/tools/install-kubectl/) guide how to install and configure `kubectl`.
- You should install Helm v3, please follow the instruction [here](https://helm.sh/docs/intro/install/) to install it.

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

```bash
$ helm install nfs-server stable/nfs-server-provisioner \
  --set persistance.enabled=true \
  --set persistance.storageClass=PERSISTENT_STORAGE_CLASS \
  --set persistance.size=PERSISTENT_SIZE
```

- `PERSISTENT_STORAGE_CLASS` is Persistent Storage Class available in your Kubernetes cluster

  Persistent Storage Classes for different providers:
  - Amazon EKS: `gp2`
  - Digital Ocean: `do-block-storage`
  - IBM Cloud: Default `ibmc-file-bronze`. [More storage classes](https://cloud.ibm.com/docs/containers?topic=containers-file_storage)
  - Yandex Cloud: `yc-network-hdd` or `yc-network-ssd`. [More details](https://cloud.yandex.ru/docs/managed-kubernetes/operations/volumes/manage-storage-class)
  - minikube: `standard`

- `PERSISTENT_SIZE` is the total size of all Persistent Storages for nfs Persistent Storage Class. You can express size as a plain integer one of these suffixes: `T`, `G`, `M`, `Ti`, `Gi`, `Mi`. For example: `8Gi`.

See more detail about install NFS Server Provisioner via Helm [here](https://github.com/helm/charts/tree/master/stable/nfs-server-provisioner#nfs-server-provisioner).

Create Persistent Volume Claim

Note: Default `nfs` Persistent Volume Claim is 8Gi. You can change it in `values.yaml` file in `persistence.storageClass` and `persistence.size` section. It should be less than `PERSISTENT_SIZE` at least by about 5%. Recommended use 8Gi or more for persistent storage for every 100 active users of ONLYOFFICE DocumentServer.


### 3. Deploy RabbitMQ

To install the RabbitMQ to your cluster, run the following command:

```bash
$ helm install rabbitmq bitnami/rabbitmq \
  --set metrics.enabled=false
```
Note: Set the metrics.enabled=true to enable exposing RabbitMQ metrics to be gathered by Prometheus.

See more details about installing RabbitMQ via Helm here.

### 4. Deploy Redis

To install Redis to your cluster, run the following command:

```bash
$ helm install redis bitnami/redis \
  --set architecture=standalone \
  --set auth.enabled=false \
  --set image.tag=5.0.7-debian-10-r51 \
  --set metrics.enabled=false
```

Note: Set the metrics.enabled=true to enable exposing Redis metrics to be gathered by Prometheus.

See more details about installing Redis via Helm here.

### 5. Deploy PostgreSQL

Download the ONLYOFFICE Docs database scheme:

```bash
wget -O createdb.sql https://raw.githubusercontent.com/ONLYOFFICE/server/master/schema/postgresql/createdb.sql
```

Create a config map from it:

```bash
$ kubectl create configmap init-db-scripts \
  --from-file=./createdb.sql
```

To install the PostgreSQL to your cluster, run the following command:

```
$ helm install postgresql bitnami/postgresql \
  --set initdbScriptsConfigMap=init-db-scripts \
  --set postgresqlDatabase=postgres \
  --set persistence.size=PERSISTENT_SIZE \
  --set metrics.enabled=false
```

Here PERSISTENT_SIZE is a size for the PostgreSQL persistent volume. For example: 8Gi.

It's recommended to use at least 2Gi of persistent storage for every 100 active users of ONLYOFFICE Docs.

Note: Set the metrics.enabled=true to enable exposing PostgreSQL metrics to be gathered by Prometheus.

See more details about installing PostgreSQL via Helm here.

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

## Deploy ONLYOFFICE DocumentServer

### 1. Deploy the ONLYOFFICE Docs license

If you have a valid ONLYOFFICE Docs license, create a secret license from the file.

```bash
$ kubectl create secret generic license \
  --from-file=./license.lic
```

Note: The source license file name should be 'license.lic' because this name would be used as a field in the created secret.

```bash
$ kubectl create secret generic license
```

### 2. Deploy ONLYOFFICE Docs

To deploy DocumentServer with the release name `documentserver`:

```bash

$ helm install documentserver ./
```

The command deploys DocumentServer on the Kubernetes cluster in the default configuration. The Parameters section lists the parameters that can be configured during installation.

### 3. Uninstall ONLYOFFICE Docs

To uninstall/delete the `documentserver` deployment:

```bash
$ helm delete my-release

```

The command removes all the Kubernetes components associated with the chart and deletes the release.

### 4. Parameters

| Parameter                         | Description                                      | Default                                     |
|-----------------------------------|--------------------------------------------------|---------------------------------------------|
| connections.dbHost                | IP address or the name of the database           | postgresql                                  |
| connections.dbUser                | database user                                    | postgres                                    |
| connections.dbPassword            | database password                                | postgres                                    |
| connections.dbPort                | database server port number                      | 5432                                        |
| connections.redistHost            | IP address or the name of the redis host         | redis-master                                |
| connections.amqpHost              | IP address or the name of the message-broker     | rabbit-mq                                   |
| connections.amqpUser              | messabe-broker user                              | user                                        |
| connections.amqpProto             | messabe-broker protocol                          | ampq                                        |
| persistance.storageClass          | storage class name                               | nfs                                         |
| persistance.size                  | storage volume size                              | 8Gi                                         |
| metrics.enabled                   | Statsd installation                              | false                                       |
| example.enabled                   | Choise of example installation                   | false                                       |
| example.containerImage            | example container image name                     | onlyoffice/docs-example:6.3.1.32            |
| docservice.replicas               | docservice replicas quantity                     | 2                                           |
| docservice.proxyContainerImage    | docservice proxy container image name            | onlyoffice/docs-proxy-de:6.3.1.32           |
| docservice.containerImage         | docservice container image name                  | onlyoffice/docs-docservice-de:6.3.1.32      |
| docservice.requests.memory        | memory request                                   | 256Mi                                       |
| docservice.requests.cpu           | cpu request                                      | 100m                                        |
| docservice.limits.memory          | memory limit                                     | 2Gi                                         |
| docservice.limits.cpu             | cpu limit                                        | 1000m                                       |
| converter.replicas                | converter replicas quantity                      | 2                                           |
| converter.containerImage          | converter container image name                   | onlyoffice/docs-converter-de:6.3.1.32       |
| converter.requests.memory         | memory request                                   | 256Mi                                       |
| converter.requests.cpu            | cpu request                                      | 100m                                        |
| converter.limits.memory           | memory limit                                     | 2Gi                                         |
| converter.limits.cpu              | cpu limit                                        | 1000m                                       |
| jwt.enabled                       | jwt enabling parameter                           | true                                        |
| jwt.secret                        | jwt secret                                       | MYSECRET                                    |
| service.type                      | documentserver service type                      | ClusterIP                                   |
| service.port                      | documentserver service port                      | 8888                                        |
| ingress.enabled                   | installation of ingress service                  | false                                       |
| ingress.ssl.enabled               | installation ssl for ingress service             | false                                       |
| ingress.ssl.host                  | host for ingress ssl                             | example.com                                 |
| ingress.ssl.secret                | secret name for ssl                              | tls                                         |

Specify each parameter using the --set key=value[,key=value] argument to helm install. For example,

```bash
$ helm install documentserver ./ --set ingress.enabled=true,ingress.ssl.enabled=true,ingress.ssl.host=your.host.com
```

This command gives expose documentServer via HTTPS.

Alternatively, a YAML file that specifies the values for the parameters can be provided while installing the chart. For example,

```bash
$ helm install my-release -f values.yaml bitnami/rabbitmq
```

> **Tip**: You can use the default [values.yaml](values.yaml)

### 5. Configuration and installation details

### 5.1 Example deployment (optional)

To deploy example set `example.install` parameter to true:

```bash
$ helm install documentserver ./ --set example.enabled=true
```

### 5.2 StatsD deployment (optional)
To deploy StatsD set `connections.metricsEnabled` to true:
```bash
$ helm install documentserver ./ --set metrics.enabled=true
```

### 5.3 Expose DocumentServer

#### 5.3.1 Expose DocumentServer via Service (HTTP Only)
*You should skip #5.1 step if you are going expose DocumentServer via HTTPS*

This type of exposure has the least overheads of performance, it creates a loadbalancer to get access to DocumentServer.
Use this type of exposure if you use external TLS termination, and don't have another WEB application in k8s cluster.

To expose DocumentServer via service set `service.type` parameter to LoadBalancer:

```bash
$ helm install documentserver ./ --set service.type=LoadBalancer --set service.port=8888

```


Run next command to get `documentserver` service IP:

```bash
$ kubectl get service documentserver -o jsonpath="{.status.loadBalancer.ingress[*].ip}"
```

After it ONLYOFFICE DocumentServer will be available at `http://DOCUMENTSERVER-SERVICE-IP/`.

If service IP is empty try getting `documentserver` service hostname

```bash
kubectl get service documentserver -o jsonpath="{.status.loadBalancer.ingress[*].hostname}"
```

In this case ONLYOFFICE DocumentServer will be available at `http://DOCUMENTSERVER-SERVICE-HOSTNAME/`.


#### 5.3.2 Expose DocumentServer via Ingress

#### 5.3.2.1 Installing the Kubernetes Nginx Ingress Controller

To install the Nginx Ingress Controller to your cluster, run the following command:

```bash
$helm install nginx-ingress ingress-nginx / ingress-nginx --set controller.publishService.enabled = true, controller.replicaCount = 2
```

See more detail about install Nginx Ingress via Helm [here](https://github.com/helm/charts/tree/master/stable/nginx-ingress#nginx-ingress).

#### 5.3.2.2 Expose DocumentServer via HTTP

*You should skip #5.2.2 step if you are going expose DocumentServer via HTTPS*

This type of exposure has more overheads of performance compared with exposure via service, it also creates a loadbalancer to get access to DocumentServer. 
Use this type if you use external TLS termination and when you have several WEB applications in the k8s cluster. You can use the one set of ingress instances and the one loadbalancer for those. It can optimize entry point performance and reduce your cluster payments, cause providers can charge a fee for each loadbalancer.

To expose DocumentServer via ingress HTTP set `ingress.enabled` parameter to true:

```bash
$ helm install documentserver ./ --set ingress.enabled=true

```

Run next command to get `documentserver` ingress IP:

```bash
$ kubectl get ingress documentserver -o jsonpath="{.status.loadBalancer.ingress[*].ip}"
```

After it ONLYOFFICE DocumentServer will be available at `http://DOCUMENTSERVER-INGRESS-IP/`.

If ingress IP is empty try getting `documentserver` ingress hostname

```bash
kubectl get ingress documentserver -o jsonpath="{.status.loadBalancer.ingress[*].hostname}"
```

In this case ONLYOFFICE DocumentServer will be available at `http://DOCUMENTSERVER-INGRESS-HOSTNAME/`.

#### 5.3.2.3 Expose DocumentServer via HTTPS

This type of exposure to enable internal TLS termination for DocumentServer.

Create `tls` secret with ssl certificate inside.

Put ssl certificate and private key into `tls.crt` and `tls.key` file and than run:

```bash
$ kubectl create secret generic tls \
  --from-file=./tls.crt \
  --from-file=./tls.key
```

```bash
$ helm install documentserver ./ --set ingress.enabled=true --set ingress.ssl.enabled=true --set ingress.ssl.host=example.com

```

Run next command to get `documentserver` ingress IP:

```bash
$ kubectl get ingress documentserver -o jsonpath="{.status.loadBalancer.ingress[*].ip}"
```

If ingress IP is empty try getting `documentserver` ingress hostname

```bash
kubectl get ingress documentserver -o jsonpath="{.status.loadBalancer.ingress[*].hostname}"
```

Associate `documentserver` ingress IP or hostname with your domain name through your DNS provider.

After it ONLYOFFICE DocumentServer will be available at `https://your-domain-name/`.

### 6. Update ONLYOFFICE Docs

#### 6.1 Manual update

*You should skip step [#6.1](#61-manual-update) if you want to perform the update using a script*

#### 6.1.1 Preparing for update

The next script creates a job, which shuts down the service, clears the cache files and clears tables in the database.

If there are `remove-db-scripts` and `init-db-scripts` configmaps, then delete them:

```bash
$ kubectl delete cm remove-db-scripts init-db-scripts
```

Download the ONLYOFFICE Docs database scripts for database cleaning and database schema creating:

```bash
$ wget -O removetbl.sql https://raw.githubusercontent.com/ONLYOFFICE/server/master/schema/postgresql/removetbl.sql
$ wget -O createdb.sql https://raw.githubusercontent.com/ONLYOFFICE/server/master/schema/postgresql/createdb.sql
```

Create a configmap from them:

```bash
$ kubectl create configmap remove-db-scripts --from-file=./removetbl.sql
$ kubectl create configmap init-db-scripts --from-file=./createdb.sql
```

Create a configmap containing the update script:

```bash
$ kubectl apply -f ./templates/configmaps/update-ds.yaml
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
$ ./templates/scripts/update-ds.sh [DOCUMENTSERVER_VERSION]
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

#### 2.1 Deploy Grafana without installing ready-made dashboards

*You should skip step [#2.1](#21-deploy-grafana-without-installing-ready-made-dashboards) if you want to Deploy Grafana with the installation of ready-made dashboards*

To install Grafana to your cluster, run the following command:

```bash
$ helm install grafana bitnami/grafana \
  --set service.port=80 \
  --set config.useGrafanaIniFile=true \
  --set config.grafanaIniConfigMap=grafana-ini \
  --set datasources.secretName=grafana-datasource
```

#### 2.2 Deploy Grafana with the installation of ready-made dashboards

Run the `./templates/metrics/get_dashboard.sh` script, which will download ready-made dashboards in `JSON` format from the Grafana [website](https://grafana.com/grafana/dashboards),
make the necessary edits to them and create a configmap from them. A dashboard will also be added to visualize metrics coming from the DocumentServer (it is assumed that step [#6](#6-deploy-statsd-exporter) has already been completed).

```
$ ./templates/metrics/get_dashboard.sh
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

Note: It is assumed that step [#5.3.2.1](#5321-installing-the-kubernetes-nginx-ingress-controller) has already been completed.

#### 3.1 Expose Grafana via HTTP
*You should skip step [#3.1](#31-expose-grafana-via-http) if you are going to expose Grafana via HTTPS*

To expose Grafana via ingress HTTP set `ingress.enabled` parameter to `true`

That you will have access to Grafana at `http://INGRESS-ADDRESS/grafana/`

#### 3.2 Expose Grafana via HTTPS

Note: It is assumed that step [#5.3.2.3](#5323-expose-documentserver-via-https) has already been completed.

After that you will have access to Grafana at `https://your-domain-name/grafana/`

### 4. View gathered metrics in Grafana

Go to the address `http(s)://your-domain-name/grafana/`

Login - admin

To get the password, run the following command:
```
$ kubectl get secret grafana-admin --namespace default -o jsonpath="{.data.GF_SECURITY_ADMIN_PASSWORD}" | base64 --decode
```

In the dashboard section, you will see the added dashboards that will display the metrics received from Prometheus.