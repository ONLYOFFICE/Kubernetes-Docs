# ONLYOFFICE Docs for Kubernetes

This repository contains a set of files to deploy ONLYOFFICE Docs into a Kubernetes cluster or OpenShift cluster.

## Contents
- [Introduction](#introduction)
- [Deploy prerequisites](#deploy-prerequisites)
  * [1. Add Helm repositories](#1-add-helm-repositories)
  * [2. Install Persistent Storage](#2-install-persistent-storage)
  * [3. Deploy RabbitMQ](#3-deploy-rabbitmq)
  * [4. Deploy Redis](#4-deploy-redis)
  * [5. Deploy Database](#5-deploy-database)
  * [6. Deploy StatsD exporter](#6-deploy-statsd-exporter)
    + [6.1 Add Helm repositories](#61-add-helm-repositories)
    + [6.2 Installing Prometheus](#62-installing-prometheus)
    + [6.3 Installing StatsD exporter](#63-installing-statsd-exporter)
  * [7. Make changes to Node-config configuration files](#7-make-changes-to-Node-config-configuration-files)
    + [7.1 Create a ConfigMap containing a json file](#71-create-a-configmap-containing-a-json-file)
    + [7.2 Specify parameters when installing ONLYOFFICE Docs](#72-specify-parameters-when-installing-onlyoffice-docs)
  * [8. Add custom Fonts](#8-add-custom-fonts)
  * [9. Add Plugins](#9-add-plugins)
  * [10. Add custom dictionaries](#10-add-custom-dictionaries)
  * [11. Change interface themes](#11-change-interface-themes)
    + [11.1 Create a ConfigMap containing a json file](#111-create-a-configmap-containing-a-json-file)
    + [11.2 Specify parameters when installing ONLYOFFICE Docs](#112-specify-parameters-when-installing-onlyoffice-docs)
  * [12. Connecting Amazon S3 bucket as a cache to ONLYOFFICE Helm Docs](#12-connecting-amazon-s3-bucket-as-a-cache-to-onlyoffice-helm-docs)
- [Deploy ONLYOFFICE Docs](#deploy-onlyoffice-docs)
  * [1. Deploy the ONLYOFFICE Docs license](#1-deploy-the-onlyoffice-docs-license)
    + [1.1 Create secret](#11-create-secret)
    + [1.2 Specify parameters when installing ONLYOFFICE Docs](#12-specify-parameters-when-installing-onlyoffice-docs)
  * [2. Deploy ONLYOFFICE Docs](#2-deploy-onlyoffice-docs)
  * [3. Uninstall ONLYOFFICE Docs](#3-uninstall-onlyoffice-docs)
  * [4. Parameters](#4-parameters)
  * [5. Configuration and installation details](#5-configuration-and-installation-details)
  * [5.1 Example deployment (optional)](#51-example-deployment-optional)
  * [5.2 Metrics deployment (optional)](#52-metrics-deployment-optional)
  * [5.3 Expose ONLYOFFICE Docs](#53-expose-onlyoffice-docs)
    + [5.3.1 Expose ONLYOFFICE Docs via Service (HTTP Only)](#531-expose-onlyoffice-docs-via-service-http-only)
    + [5.3.2 Expose ONLYOFFICE Docs via Ingress](#532-expose-onlyoffice-docs-via-ingress)
    + [5.3.2.1 Installing the Kubernetes Nginx Ingress Controller](#5321-installing-the-kubernetes-nginx-ingress-controller)
    + [5.3.2.2 Expose ONLYOFFICE Docs via HTTP](#5322-expose-onlyoffice-docs-via-http)
    + [5.3.2.3 Expose ONLYOFFICE Docs via HTTPS](#5323-expose-onlyoffice-docs-via-https)
    + [5.3.2.4 Expose ONLYOFFICE Docs via HTTPS using the Let's Encrypt certificate](#5324-expose-onlyoffice-docs-via-https-using-the-lets-encrypt-certificate)
    + [5.3.2.5 Expose ONLYOFFICE Docs on a virtual path](#5325-expose-onlyoffice-docs-on-a-virtual-path)
    + [5.3.3 Expose ONLYOFFICE Docs via route in OpenShift](#533-expose-onlyoffice-docs-via-route-in-openshift)
  * [6. Scale ONLYOFFICE Docs (optional)](#6-scale-onlyoffice-docs-optional) 
      + [6.1 Horizontal Pod Autoscaling](#61-horizontal-pod-autoscaling)
      + [6.2 Manual scaling](#62-manual-scaling) 
  * [7. Update ONLYOFFICE Docs](#7-update-onlyoffice-docs)
  * [8. Shutdown ONLYOFFICE Docs (optional)](#8-shutdown-onlyoffice-docs-optional)
  * [9. Update ONLYOFFICE Docs license (optional)](#9-update-onlyoffice-docs-license-optional)
  * [10. ONLYOFFICE Docs installation test (optional)](#10-onlyoffice-docs-installation-test-optional)
  * [11. Run Jobs in a private k8s cluster (optional)](#11-run-jobs-in-a-private-k8s-cluster-optional)
  * [12. Access to the info page (optional)](#12-access-to-the-info-page-optional)
- [Using Grafana to visualize metrics (optional)](#using-grafana-to-visualize-metrics-optional)
  * [1. Deploy Grafana](#1-deploy-grafana)
    + [1.1 Deploy Grafana without installing ready-made dashboards](#11-deploy-grafana-without-installing-ready-made-dashboards)
    + [1.2 Deploy Grafana with the installation of ready-made dashboards](#12-deploy-grafana-with-the-installation-of-ready-made-dashboards)
  * [2 Access to Grafana via Ingress](#2-access-to-grafana-via-ingress)
  * [3. View gathered metrics in Grafana](#3-view-gathered-metrics-in-grafana)

## Introduction

- You must have a Kubernetes or OpenShift cluster installed. Please, checkout [the reference](https://kubernetes.io/docs/setup/) to set up Kubernetes. Please, checkout [the reference](https://docs.openshift.com/container-platform/4.7/installing/index.html) to setup OpenShift.
- You should also have a local configured copy of `kubectl`. See [this](https://kubernetes.io/docs/tasks/tools/install-kubectl/) guide how to install and configure `kubectl`.
- You should install Helm v3.7+. Please follow the instruction [here](https://helm.sh/docs/intro/install/) to install it.
- If you use OpenShift, you can use both `oc` and `kubectl` to manage deploy. 
- If the installation of components external to ‘Docs’ is performed from Helm Chart in an OpenShift cluster, then it is recommended to install them from a user who has the `cluster-admin` role, in order to avoid possible problems with access rights. See [this](https://docs.openshift.com/container-platform/4.7/authentication/using-rbac.html) guide to add the necessary roles to the user.

## Deploy prerequisites

Note: It may be required to apply `SecurityContextConstraints` policy when installing into OpenShift cluster, which adds permission to run containers from a user whose `ID = 1001`.

To do this, run the following commands:
```
$ oc apply -f https://raw.githubusercontent.com/ONLYOFFICE/Kubernetes-Docs/master/sources/scc/helm-components.yaml
$ oc adm policy add-scc-to-group scc-helm-components system:authenticated
```

Alternatively, you can specify the allowed range of users and groups from the target namespace, see the parameters `runAsUser` and `fsGroup` while installing dependencies, such as RabbitMQ, Redis, PostgreSQL, etc.

### 1. Add Helm repositories

```bash
$ helm repo add bitnami https://charts.bitnami.com/bitnami
$ helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
$ helm repo add nfs-server-provisioner https://kubernetes-sigs.github.io/nfs-ganesha-server-and-external-provisioner
$ helm repo add onlyoffice https://download.onlyoffice.com/charts/stable
$ helm repo update
```

### 2. Install Persistent Storage

*If you want to use [Amazon S3 as a cache](#12-connecting-amazon-s3-bucket-as-a-cache-to-onlyoffice-helm-docs), please skip this step.*

Install NFS Server Provisioner

Note: When installing NFS Server Provisioner, Storage Classes - `NFS` is created. When installing to an OpenShift cluster, the user must have a role that allows you to create Storage Classes in the cluster. Read more [here](https://docs.openshift.com/container-platform/4.7/storage/dynamic-provisioning.html).

```bash
$ helm install nfs-server nfs-server-provisioner/nfs-server-provisioner \
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

- `PERSISTENT_SIZE` is the total size of all Persistent Storages for the nfs Persistent Storage Class. You can express the size as a plain integer with one of these suffixes: `T`, `G`, `M`, `Ti`, `Gi`, `Mi`. For example: `9Gi`.

See more details about installing NFS Server Provisioner via Helm [here](https://github.com/kubernetes-sigs/nfs-ganesha-server-and-external-provisioner/tree/master/charts/nfs-server-provisioner).

Configure a Persistent Volume Claim

Note: The default `nfs` Persistent Volume Claim is 8Gi. You can change it in the [values.yaml](values.yaml) file in the `persistence.storageClass` and `persistence.size` section. It should be less than `PERSISTENT_SIZE` at least by about 5%. It's recommended to use 8Gi or more for persistent storage for every 100 active users of ONLYOFFICE Docs.

*The PersistentVolume type to be used for PVC placement must support Access Mode [ReadWriteMany](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes).*
*Also, PersistentVolume must have as the owner the user from whom the ONLYOFFICE Docs will be started. By default it is `ds` (101:101).*

Note: If you want to enable `WOPI`, please set the parameter `wopi.enabled=true`. In this case Persistent Storage must be connected to the cluster nodes with the disabled caching attributes for the mounted directory for the clients. For NFS Server Provisioner it can be achieved by adding `noac` option to the parameter `storageClass.mountOptions`. Please find more information [here](https://github.com/kubernetes-sigs/nfs-ganesha-server-and-external-provisioner/blob/master/charts/nfs-server-provisioner/values.yaml#L83).
### 3. Deploy RabbitMQ

To install RabbitMQ to your cluster, run the following command:

```bash
$ helm install rabbitmq bitnami/rabbitmq \
  --set persistence.storageClass=PERSISTENT_STORAGE_CLASS \
  --set metrics.enabled=false
```

Note: Set the `metrics.enabled=true` to enable exposing RabbitMQ metrics to be gathered by Prometheus.

See more details about installing RabbitMQ via Helm [here](https://github.com/bitnami/charts/tree/main/bitnami/rabbitmq#rabbitmq).

### 4. Deploy Redis

To install Redis to your cluster, run the following command:

```bash
$ helm install redis bitnami/redis \
  --set architecture=standalone \
  --set master.persistence.storageClass=PERSISTENT_STORAGE_CLASS \
  --set metrics.enabled=false
```

Note: Set the `metrics.enabled=true` to enable exposing Redis metrics to be gathered by Prometheus.

See more details about installing Redis via Helm [here](https://github.com/bitnami/charts/tree/main/bitnami/redis).

### 5. Deploy Database

As a database server, you can use PostgreSQL, MySQL or MariaDB

**If PostgreSQL is selected as the database server, then follow these steps**

To install PostgreSQL to your cluster, run the following command:

```
$ helm install postgresql bitnami/postgresql \
  --set auth.database=postgres \
  --set primary.persistence.storageClass=PERSISTENT_STORAGE_CLASS \
  --set primary.persistence.size=PERSISTENT_SIZE \
  --set metrics.enabled=false
```

See more details about installing PostgreSQL via Helm [here](https://github.com/bitnami/charts/tree/main/bitnami/postgresql#postgresql).

**If MySQL is selected as the database server, then follow these steps**

To install MySQL to your cluster, run the following command:

```
$ helm install mysql bitnami/mysql \
  --set auth.database=onlyoffice \
  --set auth.username=onlyoffice \
  --set primary.persistence.storageClass=PERSISTENT_STORAGE_CLASS \
  --set primary.persistence.size=PERSISTENT_SIZE \
  --set metrics.enabled=false
```

See more details about installing MySQL via Helm [here](https://github.com/bitnami/charts/tree/main/bitnami/mysql).

Here `PERSISTENT_SIZE` is a size for the Database persistent volume. For example: `8Gi`.

It's recommended to use at least 2Gi of persistent storage for every 100 active users of ONLYOFFICE Docs.

Note: Set the `metrics.enabled=true` to enable exposing Database metrics to be gathered by Prometheus.

### 6. Deploy StatsD exporter

*This step is optional. You can skip step [#6](#6-deploy-statsd-exporter) entirely if you don't want to run StatsD exporter*

#### 6.1 Add Helm repositories

```bash
$ helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
$ helm repo add kube-state-metrics https://kubernetes.github.io/kube-state-metrics
$ helm repo update
```

#### 6.2 Installing Prometheus

To install Prometheus to your cluster, run the following command:

```bash
$ helm install prometheus -f https://raw.githubusercontent.com/ONLYOFFICE/Kubernetes-Docs/master/sources/extraScrapeConfigs.yaml prometheus-community/prometheus \
  --set server.global.scrape_interval=1m
```

To change the scrape interval, specify the `server.global.scrape_interval` parameter.

See more details about installing Prometheus via Helm [here](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus).

#### 6.3 Installing StatsD exporter

To install StatsD exporter to your cluster, run the following command:

```
$ helm install statsd-exporter prometheus-community/prometheus-statsd-exporter \
  --set statsd.udpPort=8125 \
  --set statsd.tcpPort=8126 \
  --set statsd.eventFlushInterval=30000ms
```

See more details about installing Prometheus StatsD exporter via Helm [here](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus-statsd-exporter).

To allow the StatsD metrics in ONLYOFFICE Docs, follow step [5.2](#52-metrics-deployment-optional)

### 7. Make changes to Node-config configuration files

*This step is optional. You can skip step [#7](#7-make-changes-to-node-config-configuration-files) entirely if you don't need to make changes to the configuration files*

#### 7.1 Create a ConfigMap containing a json file

In order to create a ConfigMap from a file that contains the `local.json` structure, you need to run the following command:

```bash
$ kubectl create configmap local-config \
  --from-file=./local.json
```

Note: Any name can be used instead of `local-config`.

#### 7.2 Specify parameters when installing ONLYOFFICE Docs

When installing ONLYOFFICE Docs, specify the `extraConf.configMap=local-config` and `extraConf.filename=local.json` parameters

Note: If you need to add a configuration file after the ONLYOFFICE Docs is already installed, you need to execute step [7.1](#71-create-a-configmap-containing-a-json-file) 
and then run the `helm upgrade documentserver onlyoffice/docs --set extraConf.configMap=local-config --set extraConf.filename=local.json --no-hooks` command or 
`helm upgrade documentserver -f ./values.yaml onlyoffice/docs --no-hooks` if the parameters are specified in the `values.yaml` file.

### 8. Add custom Fonts

*This step is optional. You can skip step [#8](#8-add-custom-fonts) entirely if you don't need to add your fonts*

In order to add fonts to images, you need to rebuild the images. Refer to the relevant steps in [this](https://github.com/ONLYOFFICE/Docker-Docs#building-onlyoffice-docs) manual.
Then specify your images when installing the ONLYOFFICE Docs.

### 9. Add Plugins

*This step is optional. You can skip step [#9](#9-add-plugins) entirely if you don't need to add plugins*

In order to add plugins to images, you need to rebuild the images. Refer to the relevant steps in [this](https://github.com/ONLYOFFICE/Docker-Docs#building-onlyoffice-docs) manual.
Then specify your images when installing the ONLYOFFICE Docs.

### 10. Add custom dictionaries

*This step is optional. You can skip step [#10](#10-add-custom-dictionaries) entirely if you don't need to add your dictionaries*

In order to add your custom dictionaries to images, you need to rebuild the images. Refer to the relevant steps in [this](https://github.com/ONLYOFFICE/Docker-Docs#building-onlyoffice-docs) manual.
Then specify your images when installing the ONLYOFFICE Docs.

### 11. Change interface themes

*This step is optional. You can skip step [#11](#11-change-interface-themes) entirely if you don't need to change the interface themes*

#### 11.1 Create a ConfigMap containing a json file

To create a ConfigMap with a json file that contains the interface themes, you need to run the following command:

```bash
$ kubectl create configmap custom-themes \
  --from-file=./custom-themes.json
```

Note: Instead of `custom-themes` and `custom-themes.json` you can use any other names.

#### 11.2 Specify parameters when installing ONLYOFFICE Docs

When installing ONLYOFFICE Docs, specify the `extraThemes.configMap=custom-themes` and `extraThemes.filename=custom-themes.json` parameters.

Note: If you need to add interface themes after the ONLYOFFICE Docs is already installed, you need to execute step [11.1](#111-create-a-configmap-containing-a-json-file)
and then run the `helm upgrade documentserver onlyoffice/docs --set extraThemes.configMap=custom-themes --set extraThemes.filename=custom-themes.json --no-hooks` command or
`helm upgrade documentserver -f ./values.yaml onlyoffice/docs --no-hooks` if the parameters are specified in the `values.yaml` file.

### 12. Connecting Amazon S3 bucket as a cache to ONLYOFFICE Helm Docs
In order to connect Amazon S3 bucket as a cache, you need to [create](#7-make-changes-to-node-config-configuration-files) a configuration file or edit the existing one in accordance with [this guide](https://helpcenter.onlyoffice.com/ru/installation/docs-connect-amazon.aspx) and change the value of the parameter `persistence.storageS3` to `true`. 

## Deploy ONLYOFFICE Docs

Note: It may be required to apply `SecurityContextConstraints` policy when installing into OpenShift cluster, which adds permission to run containers from a user whose `ID = 101`.

To do this, run the following commands:

```
$ oc apply -f https://raw.githubusercontent.com/ONLYOFFICE/Kubernetes-Docs/master/sources/scc/docs-components.yaml
$ oc adm policy add-scc-to-group scc-docs-components system:authenticated
```

Alternatively, you can apply the `nonroot-v2` `SecurityContextConstraints` (SCC) policy in the `commonAnnotations` or `annotations` for all resources that describe the podTemplate. Ensure that both the user and the service account have the necessary permissions to use this SCC. To verify who has permission to use the `nonroot-v2`, execute the following command: `oc adm policy who-can use scc nonroot-v2`

```bash
helm install documentserver onlyoffice/docs --set commonAnnotations."openshift\.io/required-scc"="nonroot-v2"
```

If required set `podSecurityContext.enabled` and `<resources>.containerSecurityContext.enabled` to `true`

### 1. Deploy the ONLYOFFICE Docs license

#### 1.1. Create secret

If you have a valid ONLYOFFICE Docs license, create a secret `license` from the file:

```
$ kubectl create secret generic [SECRET_LICENSE_NAME] --from-file=path/to/license.lic
```

- Where `SECRET_LICENSE_NAME` is the name of a future secret with a license

Note: The source license file name should be 'license.lic' because this name would be used as a field in the created secret.

Note: If the installation is performed without creating a secret with the existing license file, an empty secret `license` will be automatically created. For information on how to update an existing secret with a license, see [here](#9-update-onlyoffice-docs-license-optional).

#### 1.2. Specify parameters when installing ONLYOFFICE Docs

When installing ONLYOFFICE Docs, specify the `license.existingSecret=[SECRET_LICENSE_NAME]` parameter.

```
$ helm install documentserver onlyoffice/docs --set license.existingSecret=[SECRET_LICENSE_NAME]
```

Note: If you need to add license after the ONLYOFFICE Docs is already installed, you need to execute step [1.1](#11-create-secret) and then run the `helm upgrade documentserver onlyoffice/docs --set license.existingSecret=[SECRET_LICENSE_NAME] --no-hooks` command or `helm upgrade documentserver -f ./values.yaml onlyoffice/docs --no-hooks` if the parameters are specified in the `values.yaml` file.

### 2. Deploy ONLYOFFICE Docs

To deploy ONLYOFFICE Docs with the release name `documentserver`:

```bash
$ helm install documentserver onlyoffice/docs
```

The command deploys ONLYOFFICE Docs on the Kubernetes cluster in the default configuration. The [Parameters](#4-parameters) section lists the parameters that can be configured during installation.

Note: When installing ONLYOFFICE Docs in a private k8s cluster behind a Web proxy or with no internet access, see the [notes](#11-run-jobs-in-a-private-k8s-cluster-optional) below.

### 3. Uninstall ONLYOFFICE Docs

To uninstall/delete the `documentserver` deployment:

```bash
$ helm delete documentserver
```

Executing the `helm delete` command launches hooks, which perform some preparatory actions before completely deleting the ONLYOFFICE Docs, which include stopping the server, cleaning up the used PVC and database tables.
The default hook execution time is 300s. The execution time can be changed using `--timeout [time]`, for example:

```bash
$ helm delete documentserver --timeout 25m
```

Note: When deleting ONLYOFFICE Docs in a private k8s cluster behind a Web proxy or with no internet access, see the [notes](#11-run-jobs-in-a-private-k8s-cluster-optional) below.

If you want to delete the ONLYOFFICE Docs without any preparatory actions, run the following command:

```bash
$ helm delete documentserver --no-hooks
```

The `helm delete` command removes all the Kubernetes components associated with the chart and deletes the release.

### 4. Parameters

| Parameter                                                   | Description                                                                                                                                                                    | Default                                                                                   |
|-------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| `connections.dbType`                                        | The database type. Possible values are `postgres`, `mariadb`, `mysql`, `oracle`, `mssql` or `dameng`                                                                           | `postgres`                                                                                |
| `connections.dbHost`                                        | The IP address or the name of the Database host                                                                                                                                | `postgresql`                                                                              |
| `connections.dbUser`                                        | Database user                                                                                                                                                                  | `postgres`                                                                                |
| `connections.dbPort`                                        | Database server port number                                                                                                                                                    | `5432`                                                                                    |
| `connections.dbName`                                        | Name of the Database database the application will be connected with                                                                                                           | `postgres`                                                                                |
| `connections.dbPassword`                                    | Database user password. If set to, it takes priority over the `connections.dbExistingSecret`                                                                                   | `""`                                                                                      |
| `connections.dbSecretKeyName`                               | The name of the key that contains the Database user password                                                                                                                   | `postgres-password`                                                                       |
| `connections.dbExistingSecret`                              | Name of existing secret to use for Database passwords. Must contain the key specified in `connections.dbSecretKeyName`                                                         | `postgresql`                                                                              |
| `connections.redisConnectorName`                            | Defines which connector to use to connect to Redis. If you need to connect to Redis Sentinel, set the value `ioredis`                                                          | `redis`                                                                                   |
| `connections.redistHost`                                    | The IP address or the name of the Redis host. Not used if the values are set in `connections.redisClusterNodes` and `connections.redisSentinelNodes`                           | `redis-master`                                                                            |
| `connections.redisPort`                                     | The Redis server port number. Not used if the values are set in `connections.redisClusterNodes` and `connections.redisSentinelNodes`                                           | `6379`                                                                                    |
| `connections.redisUser`                                     | The Redis [user](https://redis.io/docs/management/security/acl/) name. The value in this parameter overrides the value set in the `options` object in `local.json` if you add custom configuration file | `default`                                                        |
| `connections.redisDBNum`                                    | Number of the redis logical database to be [selected](https://redis.io/commands/select/). The value in this parameter overrides the value set in the `options` object in `local.json` if you add custom configuration file | `0`                                           |
| `connections.redisClusterNodes`                             | List of nodes in the Redis cluster. There is no need to specify every node in the cluster, 3 should be enough. You can specify multiple values. It must be specified in the `host:port` format | `[]`                                                                      |
| `connections.redisPassword`                                 | The password set for the Redis account. If set to, it takes priority over the `connections.redisExistingSecret`. The value in this parameter overrides the value set in the `options` object in `local.json` if you add custom configuration file | `""`                   |
| `connections.redisSecretKeyName`                            | The name of the key that contains the Redis user password                                                                                                                      | `redis-password`                                                                          |
| `connections.redisExistingSecret`                           | Name of existing secret to use for Redis passwords. Must contain the key specified in `connections.redisSecretKeyName`. The password from this secret overrides password set in the `options` object in `local.json` | `redis`                                             |
| `connections.redisNoPass`                                   | Defines whether to use a Redis auth without a password. If the connection to Redis server does not require a password, set the value to `true`                                 | `false`                                                                                   |
| `connections.redisSentinelNodes`                            | List of Redis Sentinel Nodes. There is no need to specify every node, 3 should be enough. You can specify multiple values. It must be specified in the `host:port` format. Used if `connections.redisConnectorName` is set to `ioredis` | `[]`                             |
| `connections.redisSentinelGroupName`                        | Name of a group of Redis instances composed of a master and one or more slaves. Used if `connections.redisConnectorName` is set to `ioredis`                                   | `mymaster`                                                                                |
| `connections.redisSentinelExistingSecret`                   | Name of existing secret to use for Redis Sentinel password. Must contain the key specified in `connections.redisSentinelSecretKeyName`. The password from this secret overrides the value for the password set in the `iooptions` object in `local.json` | ""              |
| `connections.redisSentinelSecretKeyName`                    | The name of the key that contains the Redis Sentinel user password. If you set a password in `redisSentinelPassword`, a secret will be automatically created, the key name of which will be the value set here | `sentinel-password`                                       |
| `connections.redisSentinelPassword`                         | The password set for the Redis Sentinel account. If set to, it takes priority over the `connections.redisSentinelExistingSecret`. The value in this parameter overrides the value set in the `iooptions` object in `local.json` | `""`                                     |
| `connections.redisSentinelNoPass`                           | Defines whether to use a Redis Sentinel auth without a password. If the connection to Redis Sentinel does not require a password, set the value to `true`                      | `true`                                                                                    |
| `connections.amqpType`                                      | Defines the AMQP server type. Possible values are `rabbitmq` or `activemq`                                                                                                     | `rabbitmq`                                                                                |
| `connections.amqpHost`                                      | The IP address or the name of the AMQP server                                                                                                                                  | `rabbitmq`                                                                                |
| `connections.amqpPort`                                      | The port for the connection to AMQP server                                                                                                                                     | `5672`                                                                                    |
| `connections.amqpVhost`                                     | The virtual host for the connection to AMQP server                                                                                                                             | `/`                                                                                       |
| `connections.amqpUser`                                      | The username for the AMQP server account                                                                                                                                       | `user`                                                                                    |
| `connections.amqpProto`                                     | The protocol for the connection to AMQP server                                                                                                                                 | `amqp`                                                                                    |
| `connections.amqpPassword`                                  | AMQP server user password. If set to, it takes priority over the `connections.amqpExistingSecret`                                                                              | `""`                                                                                      |
| `connections.amqpSecretKeyName`                             | The name of the key that contains the AMQP server user password                                                                                                                | `rabbitmq-password`                                                                       |
| `connections.amqpExistingSecret`                            | The name of existing secret to use for AMQP server passwords. Must contain the key specified in `connections.amqpSecretKeyName`                                                | `rabbitmq`                                                                                |
| `persistence.existingClaim`                                 | Name of an existing PVC to use. If not specified, a PVC named "ds-files" will be created                                                                                       | `""`                                                                                      |
| `persistence.annotations`                                   | Defines annotations that will be additionally added to "ds-files" PVC. If set to, it takes priority over the `commonAnnotations`                                               | `{}`                                                                                      |
| `persistence.storageClass`                                  | PVC Storage Class for Onlyoffice Docs data and runtime config volumes                                                                                                          | `nfs`                                                                                     |
| `persistence.size`                                          | PVC Storage Request for ONLYOFFICE Docs volume                                                                                                                                 | `8Gi`                                                                                     |
| `persistence.storageS3`                                     | Defines whether S3 will be used as cache storage. Set to `true` if you will use S3 as cache storage                                                                            | `false`                                                                                   |
| `persistence.runtimeConfig.enabled`                         | Defines whether to use PVC and whether to mount it in containers                                                                                                               | `true`                                                                                    |
| `persistence.runtimeConfig.existingClaim`                   | The name of the existing PVC used to store the runtime config. If not specified, a PVC named "ds-runtime-config" will be created                                               | `""`                                                                                      |
| `persistence.runtimeConfig.annotations`                     | Defines annotations that will be additionally added to "ds-runtime-config" PVC. If set to, it takes priority over the `commonAnnotations`                                      | `{}`                                                                                      |
| `persistence.runtimeConfig.size`                            | PVC Storage Request for runtime config volume                                                                                                                                  | `1Gi`                                                                                     |
| `commonNameSuffix`                                          | The name that will be added to the name of all created resources as a suffix                                                                                                   | `""`                                                                                      |
| `namespaceOverride`                                         | The name of the namespace in which Onlyoffice Docs will be deployed. If not set, the name will be taken from `.Release.Namespace`                                              | `""`                                                                                      |
| `commonLabels`                                              | Defines labels that will be additionally added to all the deployed resources. You can also use `tpl` as the value for the key                                                  | `{}`                                                                                      |
| `commonAnnotations`                                         | Defines annotations that will be additionally added to all the deployed resources. You can also use `tpl` as the value for the key. Some resources may override the values specified here with their own | `{}`                                                            |
| `serviceAccount.create`                                     | Enable ServiceAccount creation                                                                                                                                                 | `false`                                                                                   |
| `serviceAccount.name`                                       | Name of the ServiceAccount to be used. If not set and `serviceAccount.create` is `true` the name will be taken from `.Release.Name` or `serviceAccount.create` is `false` the name will be "default" | `""`                                                                |
| `serviceAccount.annotations`                                | Map of annotations to add to the ServiceAccount. If set to, it takes priority over the `commonAnnotations`                                                                     | `{}`                                                                                      |
| `serviceAccount.automountServiceAccountToken`               | Enable auto mount of ServiceAccountToken on the serviceAccount created. Used only if `serviceAccount.create` is `true`                                                         | `true`                                                                                    |
| `license.existingSecret`                                    | Name of the existing secret that contains the license. Must contain the key `license.lic`                                                                                      | `""`                                                                                      |
| `license.existingClaim`                                     | Name of the existing PVC in which the license is stored. Must contain the file `license.lic`                                                                                   | `""`                                                                                      |
| `log.level`                                                 | Defines the type and severity of a logged event. Possible values are `ALL`, `TRACE`, `DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL`, `MARK`, `OFF`                                  | `WARN`                                                                                    |
| `log.type`                                                  | Defines the format of a logged event. Possible values are `pattern`, `json`, `basic`, `coloured`, `messagePassThrough`, `dummy`                                                | `pattern`                                                                                 |
| `log.pattern`                                               | Defines the log [pattern](https://github.com/log4js-node/log4js-node/blob/master/docs/layouts.md#pattern-format) if `log.type=pattern`                                         | `[%d] [%p] %c - %.10000m`                                                                 |
| `wopi.enabled`                                              | Defines if `WOPI` is enabled. If the parameter is enabled, then caching attributes for the mounted directory (`PVC`) should be disabled for the client                         | `false`                                                                                   |
| `wopi.keys.generation`                                      | Defines whether to generate API keys. Used if you set `wopi.enabled` to `true`                                                                                                 | `true`                                                                                    |
| `wopi.keys.newKeysExistingSecret`                           | Name of existing secret containing the WOPI keys. Must contain the keys `WOPI_PRIVATE_KEY`, `WOPI_PUBLIC_KEY`, `WOPI_MODULUS_KEY` and `WOPI_EXPONENT_KEY`. If not set, new keys will be generated and a secret will be created from them | `""`                            |
| `wopi.keys.oldKeysExistingSecret`                           | Name of existing secret containing the old WOPI keys. Must contain the keys `WOPI_PRIVATE_KEY_OLD`, `WOPI_PUBLIC_KEY_OLD`, `WOPI_MODULUS_KEY_OLD` and `WOPI_EXPONENT_KEY_OLD`. If not set, new keys will be generated and a secret will be created from them | `""`        |
| `metrics.enabled`                                           | Specifies the enabling StatsD for ONLYOFFICE Docs                                                                                                                              | `false`                                                                                   |
| `metrics.host`                                              | Defines StatsD listening host                                                                                                                                                  | `statsd-exporter-prometheus-statsd-exporter`                                              |
| `metrics.port`                                              | Defines StatsD listening port                                                                                                                                                  | `8125`                                                                                    |
| `metrics.prefix`                                            | Defines StatsD metrics prefix for backend services                                                                                                                             | `ds.`                                                                                     |
| `extraConf.configMap`                                       | The name of the ConfigMap containing the json file that override the default values                                                                                            | `""`                                                                                      |
| `extraConf.filename`                                        | The name of the json file that contains custom values. Must be the same as the `key` name in `extraConf.ConfigMap`                                                             | `local.json`                                                                              |
| `extraThemes.configMap`                                     | The name of the ConfigMap containing the json file that contains the interface themes                                                                                          | `""`                                                                                      |
| `extraThemes.filename`                                      | The name of the json file that contains custom interface themes. Must be the same as the `key` name in `extraThemes.configMap`                                                 | `custom-themes.json`                                                                      |
| `podAntiAffinity.type`                                      | Types of Pod antiaffinity. Allowed values: `soft` or `hard`                                                                                                                    | `soft`                                                                                    |
| `podAntiAffinity.topologyKey`                               | Node label key to match                                                                                                                                                        | `kubernetes.io/hostname`                                                                  |
| `podAntiAffinity.weight`                                    | Priority when selecting node. It is in the range from 1 to 100                                                                                                                 | `100`                                                                                     |
| `nodeSelector`                                              | Node labels for pods assignment. Each ONLYOFFICE Docs services can override the values specified here with its own                                                             | `{}`                                                                                      |
| `tolerations`                                               | Tolerations for pods assignment. Each ONLYOFFICE Docs services can override the values specified here with its own                                                             | `[]`                                                                                      |
| `imagePullSecrets`                                          | Container image registry secret name                                                                                                                                           | `""`                                                                                      |
| `requestFilteringAgent.allowPrivateIPAddress`               | Defines if it is allowed to connect private IP address or not. `requestFilteringAgent` parameters are used if JWT is disabled: `jwt.enabled=false`                             | `false`                                                                                   |
| `requestFilteringAgent.allowMetaIPAddress`                  | Defines if it is allowed to connect meta address or not                                                                                                                        | `false`                                                                                   |
| `requestFilteringAgent.allowIPAddressList`                  | Defines the list of IP addresses allowed to connect. This values are preferred than `requestFilteringAgent.denyIPAddressList`                                                  | `[]`                                                                                      |
| `requestFilteringAgent.denyIPAddressList`                   | Defines the list of IP addresses allowed to connect                                                                                                                            | `[]`                                                                                      |
| `docservice.annotations`                                    | Defines annotations that will be additionally added to Docservice Deployment. If set to, it takes priority over the `commonAnnotations`                                        | `{}`                                                                                      |
| `docservice.podAnnotations`                                 | Map of annotations to add to the Docservice deployment pods                                                                                                                    | `rollme: "{{ randAlphaNum 5 \| quote }}"`                                                 |
| `docservice.replicas`                                       | Docservice replicas quantity. If the `docservice.autoscaling.enabled` parameter is enabled, it is ignored                                                                      | `2`                                                                                       |
| `docservice.updateStrategy.type`                            | Docservice deployment update strategy type                                                                                                                                     | `Recreate`                                                                                |
| `docservice.customPodAntiAffinity`                          | Prohibiting the scheduling of Docservice Pods relative to other Pods containing the specified labels on the same node                                                          | `{}`                                                                                      |
| `docservice.podAffinity`                                    | Defines [Pod affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity) rules for Docservice Pods scheduling by nodes relative to other Pods | `{}`                                                          |
| `docservice.nodeAffinity`                                   | Defines [Node affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity) rules for Docservice Pods scheduling by nodes                  | `{}`                                                                                      |
| `docservice.nodeSelector`                                   | Node labels for Docservice Pods assignment. If set to, it takes priority over the `nodeSelector`                                                                               | `{}`                                                                                      |
| `docservice.tolerations`                                    | Tolerations for Docservice Pods assignment. If set to, it takes priority over the `tolerations`                                                                                | `[]`                                                                                      |
| `docservice.terminationGracePeriodSeconds`                  | The time to terminate gracefully during which the Docservice Pod will have the `Terminating` status                                                                            | `30`                                                                                      |
| `docservice.hostAliases`                                    | Adds [additional entries](https://kubernetes.io/docs/tasks/network/customize-hosts-file-for-pods/) to the hosts file in the Docservice and Proxy containers                    | `[]`                                                                                      |
| `docservice.initContainers`                                 | Defines containers that run before docservice and proxy containers in the Docservice deployment pod. For example, a container that changes the owner of the PersistentVolume   | `[]`                                                                                      |
| `docservice.image.repository`                               | Docservice container image repository*                                                                                                                                         | `onlyoffice/docs-docservice-de`                                                           |
| `docservice.image.tag`                                      | Docservice container image tag                                                                                                                                                 | `9.0.3-1`                                                                                 |
| `docservice.image.pullPolicy`                               | Docservice container image pull policy                                                                                                                                         | `IfNotPresent`                                                                            |
| `docservice.containerSecurityContext.enabled`               | Enable security context for the Docservice container                                                                                                                           | `false`                                                                                   |
| `docservice.lifecycleHooks`                                 | Defines the Docservice [container lifecycle hooks](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks). It is used to trigger events to run at certain points in a container's lifecycle | `{}`                                                      |
| `docservice.resources.requests`                             | The requested resources for the Docservice container                                                                                                                           | `{}`                                                                                      |
| `docservice.resources.limits`                               | The resources limits for the Docservice container                                                                                                                              | `{}`                                                                                      |
| `docservice.extraEnvVars`                                   | An array with extra env variables for the Docservice container                                                                                                                 | `[]`                                                                                      |
| `docservice.extraVolumes`                                   | An array with extra volumes for the Docservice Pod                                                                                                                             | `[]`                                                                                      |
| `docservice.extraVolumeMounts`                              | An array with extra volume mounts for the Docservice container                                                                                                                 | `[]`                                                                                      |
| `docservice.readinessProbe.enabled`                         | Enable readinessProbe for Docservice container                                                                                                                                 | `true`                                                                                    |
| `docservice.livenessProbe.enabled`                          | Enable livenessProbe for Docservice container                                                                                                                                  | `true`                                                                                    |
| `docservice.startupProbe.enabled`                           | Enable startupProbe for Docservice container                                                                                                                                   | `true`                                                                                    |
| `docservice.autoscaling.enabled`                            | Enable Docservice deployment autoscaling                                                                                                                                       | `false`                                                                                   |
| `docservice.autoscaling.annotations`                        | Defines annotations that will be additionally added to Docservice deployment HPA. If set to, it takes priority over the `commonAnnotations`                                    | `{}`                                                                                      |
| `docservice.autoscaling.minReplicas`                        | Docservice deployment autoscaling minimum number of replicas                                                                                                                   | `2`                                                                                       |
| `docservice.autoscaling.maxReplicas`                        | Docservice deployment autoscaling maximum number of replicas                                                                                                                   | `4`                                                                                       |
| `docservice.autoscaling.targetCPU.enabled`                  | Enable autoscaling of Docservice deployment by CPU usage percentage                                                                                                            | `true`                                                                                    |
| `docservice.autoscaling.targetCPU.utilizationPercentage`    | Docservice deployment autoscaling target CPU percentage                                                                                                                        | `70`                                                                                      |
| `docservice.autoscaling.targetMemory.enabled`               | Enable autoscaling of Docservice deployment by memory usage percentage                                                                                                         | `false`                                                                                   |
| `docservice.autoscaling.targetMemory.utilizationPercentage` | Docservice deployment autoscaling target memory percentage                                                                                                                     | `70`                                                                                      |
| `docservice.autoscaling.customMetricsType`                  | Custom, additional or external autoscaling metrics for the Docservice deployment                                                                                               | `[]`                                                                                      |
| `docservice.autoscaling.behavior`                           | Configuring Docservice deployment scaling behavior policies for the `scaleDown` and `scaleUp` fields                                                                           | `{}`                                                                                      |
| `proxy.accessLog`                                           | Defines the nginx config [access_log](https://nginx.org/en/docs/http/ngx_http_log_module.html#access_log) format directive                                                     | `off`                                                                                     |
| `proxy.logFormat`                                           | Defines the [format](https://nginx.org/en/docs/http/ngx_http_log_module.html#log_format) of log entries using text and various variables                                       | `'$remote_addr - $remote_user [$time_local] "$request" ' '$status $body_bytes_sent "$http_referer" ' '"$http_user_agent" "$http_x_forwarded_for"'` |
| `proxy.gzipProxied`                                         | Defines the nginx config [gzip_proxied](https://nginx.org/en/docs/http/ngx_http_gzip_module.html#gzip_proxied) directive                                                       | `off`                                                                                     |
| `proxy.clientMaxBodySize`                                   | Defines the nginx config [client_max_body_size](https://nginx.org/en/docs/http/ngx_http_core_module.html#client_max_body_size) directive                                       | `100m`                                                                                    |
| `proxy.workerConnections`                                   | Defines the nginx config [worker_connections](https://nginx.org/en/docs/ngx_core_module.html#worker_connections) directive                                                     | `4096`                                                                                    |
| `proxy.secureLinkSecret`                                    | Defines secret for the nginx config directive [secure_link_md5](https://nginx.org/en/docs/http/ngx_http_secure_link_module.html#secure_link_md5). If the value is empty, a random one will be generated, which will be used later in the upgrade. If a value is set, it will be used | `""` |
| `proxy.secureLinkExistingSecret`                            | Name of existing secret to use for secure_link. If set to, it takes priority over the `proxy.secureLinkSecret`                                                                 | `""`                                                                                      |
| `proxy.infoAllowedIP`                                       | Defines ip addresses for accessing the info page                                                                                                                               | `[]`                                                                                      |
| `proxy.infoAllowedUser`                                     | Defines user name for accessing the info page. If not set to, Nginx [Basic Authentication](https://nginx.org/en/docs/http/ngx_http_auth_basic_module.html) will not be applied to access the info page. For more details, see [here](#12-access-to-the-info-page-optional) | `""` |
| `proxy.infoAllowedPassword`                                 | Defines user password for accessing the info page. Used if `proxy.infoAllowedUser` is set. If the value is empty, a random one will be generated, which will be used later in the upgrade. If a value is set, it will be used | `""`                                       |
| `proxy.infoAllowedSecretKeyName`                            | The name of the key that contains the info auth user password. Used if `proxy.infoAllowedUser` is set                                                                          | `info-auth-password`                                                                      |
| `proxy.infoAllowedExistingSecret`                           | Name of existing secret to use for info auth password. Used if `proxy.infoAllowedUser` is set. Must contain the key specified in `proxy.infoAllowedSecretKeyName`. If set to, it takes priority over the `proxy.infoAllowedPassword` | `""`                                |
| `proxy.welcomePage.enabled`                                 | Defines whether the welcome page will be displayed                                                                                                                             | `true`                                                                                    |
| `proxy.image.repository`                                    | Docservice Proxy container image repository*                                                                                                                                   | `onlyoffice/docs-proxy-de`                                                                |
| `proxy.image.tag`                                           | Docservice Proxy container image tag                                                                                                                                           | `9.0.3-1`                                                                                 |
| `proxy.image.pullPolicy`                                    | Docservice Proxy container image pull policy                                                                                                                                   | `IfNotPresent`                                                                            |
| `proxy.containerSecurityContext.enabled`                    | Enable security context for the Proxy container                                                                                                                                | `false`                                                                                   |
| `proxy.lifecycleHooks`                                      | Defines the Proxy [container lifecycle hooks](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks). It is used to trigger events to run at certain points in a container's lifecycle | `{}`                                                           |
| `proxy.resources.requests`                                  | The requested resources for the Proxy container                                                                                                                                | `{}`                                                                                      |
| `proxy.resources.limits`                                    | The resources limits for the Proxy container                                                                                                                                   | `{}`                                                                                      |
| `proxy.extraEnvVars`                                        | An array with extra env variables for the Proxy container                                                                                                                      | `[]`                                                                                      |
| `proxy.extraVolumeMounts`                                   | An array with extra volume mounts for the Proxy container                                                                                                                      | `[]`                                                                                      |
| `proxy.readinessProbe.enabled`                              | Enable readinessProbe for  Proxy container                                                                                                                                     | `true`                                                                                    |
| `proxy.livenessProbe.enabled`                               | Enable livenessProbe for Proxy container                                                                                                                                       | `true`                                                                                    |
| `proxy.startupProbe.enabled`                                | Enable startupProbe for Proxy container                                                                                                                                        | `true`                                                                                    |
| `converter.annotations`                                     | Defines annotations that will be additionally added to Converter Deployment. If set to, it takes priority over the `commonAnnotations`                                         | `{}`                                                                                      |
| `converter.podAnnotations`                                  | Map of annotations to add to the Converter deployment pods                                                                                                                     | `rollme: "{{ randAlphaNum 5 \| quote }}"`                                                 |
| `converter.replicas`                                        | Converter replicas quantity. If the `converter.autoscaling.enabled` parameter is enabled, it is ignored                                                                        | `2`                                                                                       |
| `converter.updateStrategy.type`                             | Converter deployment update strategy type                                                                                                                                      | `Recreate`                                                                                |
| `converter.customPodAntiAffinity`                           | Prohibiting the scheduling of Converter Pods relative to other Pods containing the specified labels on the same node                                                           | `{}`                                                                                      |
| `converter.podAffinity`                                     | Defines [Pod affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity) rules for Converter Pods scheduling by nodes relative to other Pods | `{}`                                                           |
| `converter.nodeAffinity`                                    | Defines [Node affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity) rules for Converter Pods scheduling by nodes                   | `{}`                                                                                      |
| `converter.nodeSelector`                                    | Node labels for Converter Pods assignment. If set to, it takes priority over the `nodeSelector`                                                                                | `{}`                                                                                      |
| `converter.tolerations`                                     | Tolerations for Converter Pods assignment. If set to, it takes priority over the `tolerations`                                                                                 | `[]`                                                                                      |
| `converter.terminationGracePeriodSeconds`                   | The time to terminate gracefully during which the Converter Pod will have the `Terminating` status                                                                             | `30`                                                                                      |
| `converter.hostAliases`                                     | Adds [additional entries](https://kubernetes.io/docs/tasks/network/customize-hosts-file-for-pods/) to the hosts file in the Converter container                                | `[]`                                                                                      |
| `converter.initContainers`                                  | Defines containers that run before Converter container in the Converter deployment pod. For example, a container that changes the owner of the PersistentVolume   | `[]`                                                                                      |
| `converter.image.repository`                                | Converter container image repository*                                                                                                                                          | `onlyoffice/docs-converter-de`                                                            |
| `converter.image.tag`                                       | Converter container image tag                                                                                                                                                  | `9.0.3-1`                                                                                 |
| `converter.image.pullPolicy`                                | Converter container image pull policy                                                                                                                                          | `IfNotPresent`                                                                            |
| `converter.containerSecurityContext.enabled`                | Enable security context for the Converter container                                                                                                                            | `false`                                                                                   |
| `converter.lifecycleHooks`                                  | Defines the Converter [container lifecycle hooks](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks). It is used to trigger events to run at certain points in a container's lifecycle | `{}`                                                       |
| `converter.resources.requests`                              | The requested resources for the Converter container                                                                                                                            | `{}`                                                                                      |
| `converter.resources.limits`                                | The resources limits for the Converter container                                                                                                                               | `{}`                                                                                      |
| `converter.extraEnvVars`                                    | An array with extra env variables for the Converter container                                                                                                                  | `[]`                                                                                      |
| `converter.extraVolumes`                                    | An array with extra volumes for the Converter Pod                                                                                                                              | `[]`                                                                                      |
| `converter.extraVolumeMounts`                               | An array with extra volume mounts for the Converter container                                                                                                                  | `[]`                                                                                      |
| `converter.autoscaling.enabled`                             | Enable Converter deployment autoscaling                                                                                                                                        | `false`                                                                                   |
| `converter.autoscaling.annotations`                         | Defines annotations that will be additionally added to Converter deployment HPA. If set to, it takes priority over the `commonAnnotations`                                     | `{}`                                                                                      |
| `converter.autoscaling.minReplicas`                         | Converter deployment autoscaling minimum number of replicas                                                                                                                    | `2`                                                                                       |
| `converter.autoscaling.maxReplicas`                         | Converter deployment autoscaling maximum number of replicas                                                                                                                    | `16`                                                                                      |
| `converter.autoscaling.targetCPU.enabled`                   | Enable autoscaling of converter deployment by CPU usage percentage                                                                                                             | `true`                                                                                    |
| `converter.autoscaling.targetCPU.utilizationPercentage`     | Converter deployment autoscaling target CPU percentage                                                                                                                         | `70`                                                                                      |
| `converter.autoscaling.targetMemory.enabled`                | Enable autoscaling of Converter deployment by memory usage percentage                                                                                                          | `false`                                                                                   |
| `converter.autoscaling.targetMemory.utilizationPercentage`  | Converter deployment autoscaling target memory percentage                                                                                                                      | `70`                                                                                      |
| `converter.autoscaling.customMetricsType`                   | Custom, additional or external autoscaling metrics for the Converter deployment                                                                                                | `[]`                                                                                      |
| `converter.autoscaling.behavior`                            | Configuring Converter deployment scaling behavior policies for the `scaleDown` and `scaleUp` fields                                                                            | `{}`                                                                                      |
| `example.enabled`                                           | Enables the installation of Example                                                                                                                                            | `false`                                                                                   |
| `example.annotations`                                       | Defines annotations that will be additionally added to Example StatefulSet. If set to, it takes priority over the `commonAnnotations`                                          | `{}`                                                                                      |
| `example.podAnnotations`                                    | Map of annotations to add to the example pod                                                                                                                                   | `rollme: "{{ randAlphaNum 5 \| quote }}"`                                                 |
| `example.updateStrategy.type`                               | Example StatefulSet update strategy type                                                                                                                                       | `RollingUpdate`                                                                           |
| `example.customPodAntiAffinity`                             | Prohibiting the scheduling of Example Pod relative to other Pods containing the specified labels on the same node                                                              | `{}`                                                                                      |
| `example.podAffinity`                                       | Defines [Pod affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity) rules for Example Pod scheduling by nodes relative to other Pods | `{}`                                                              |
| `example.nodeAffinity`                                      | Defines [Node affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity) rules for Example Pod scheduling by nodes                      | `{}`                                                                                      |
| `example.nodeSelector`                                      | Node labels for Example Pods assignment. If set to, it takes priority over the `nodeSelector`                                                                                  | `{}`                                                                                      |
| `example.tolerations`                                       | Tolerations for Example Pods assignment. If set to, it takes priority over the `tolerations`                                                                                   | `[]`                                                                                      |
| `example.terminationGracePeriodSeconds`                     | The time to terminate gracefully during which the Example Pod will have the `Terminating` status                                                                               | `30`                                                                                      |
| `example.hostAliases`                                       | Adds [additional entries](https://kubernetes.io/docs/tasks/network/customize-hosts-file-for-pods/) to the hosts file in the Example container                                  | `[]`                                                                                      |
| `example.initContainers`                                    | Defines containers that run before Example container in the Pod                                                                                                                | `[]`                                                                                      |
| `example.image.repository`                                  | Example container image name                                                                                                                                                   | `onlyoffice/docs-example`                                                                 |
| `example.image.tag`                                         | Example container image tag                                                                                                                                                    | `9.0.3-1`                                                                                 |
| `example.image.pullPolicy`                                  | Example container image pull policy                                                                                                                                            | `IfNotPresent`                                                                            |
| `example.containerSecurityContext.enabled`                  | Enable security context for the Example container                                                                                                                              | `false`                                                                                   |
| `example.dsUrl`                                             | ONLYOFFICE Docs external address. It should be changed only if it is necessary to check the operation of the conversion in Example (e.g. http://\<documentserver-address\>/)   | `/`                                                                                       |
| `example.resources.requests`                                | The requested resources for the Example container                                                                                                                              | `{}`                                                                                      |
| `example.resources.limits`                                  | The resources limits for the Example container                                                                                                                                 | `{}`                                                                                      |
| `example.extraEnvVars`                                      | An array with extra env variables for the Example container                                                                                                                    | `[]`                                                                                      |
| `example.extraConf.configMap`                               | The name of the ConfigMap containing the json file that override the default values. See an example of creation [here](https://github.com/ONLYOFFICE/Kubernetes-Docs?tab=readme-ov-file#71-create-a-configmap-containing-a-json-file) | `""`                               |
| `example.extraConf.filename`                                | The name of the json file that contains custom values. Must be the same as the `key` name in `example.extraConf.ConfigMap`                                                     | `local.json`                                                                              |
| `example.extraVolumes`                                      | An array with extra volumes for the Example Pod                                                                                                                                | `[]`                                                                                      |
| `example.extraVolumeMounts`                                 | An array with extra volume mounts for the Example container                                                                                                                    | `[]`                                                                                      |
| `jwt.enabled`                                               | Specifies the enabling the JSON Web Token validation by the ONLYOFFICE Docs. Common for inbox and outbox requests                                                              | `true`                                                                                    |
| `jwt.secret`                                                | Defines the secret key to validate the JSON Web Token in the request to the ONLYOFFICE Docs. Common for inbox and outbox requests. If the value is empty, a random one will be generated, which will be used later in the upgrade. If a value is set, it will be used | `""` |
| `jwt.header`                                                | Defines the http header that will be used to send the JSON Web Token. Common for inbox and outbox requests                                                                     | `Authorization`                                                                           |
| `jwt.inBody`                                                | Specifies the enabling the token validation in the request body to the ONLYOFFICE Docs                                                                                         | `false`                                                                                   |
| `jwt.inbox`                                                 | JSON Web Token validation parameters for inbox requests only. If not specified, the values of the parameters of the common `jwt` are used                                      | `{}`                                                                                      |
| `jwt.outbox`                                                | JSON Web Token validation parameters for outbox requests only. If not specified, the values of the parameters of the common `jwt` are used                                     | `{}`                                                                                      |
| `jwt.existingSecret`                                        | The name of an existing secret containing variables for jwt. If not specified, a secret named `jwt` will be created                                                            | `""`                                                                                      |
| `service.existing`                                          | The name of an existing service for ONLYOFFICE Docs. If not specified, a service named `documentserver` will be created                                                        | `""`                                                                                      |
| `service.annotations`                                       | Map of annotations to add to the ONLYOFFICE Docs service. If set to, it takes priority over the `commonAnnotations`                                                            | `{}`                                                                                      |
| `service.type`                                              | ONLYOFFICE Docs service type                                                                                                                                                   | `ClusterIP`                                                                               |
| `service.port`                                              | ONLYOFFICE Docs service port                                                                                                                                                   | `8888`                                                                                    |
| `service.sessionAffinity`                                   | [Session Affinity](https://kubernetes.io/docs/reference/networking/virtual-ips/#session-affinity) for ONLYOFFICE Docs service. If not set, `None` will be set as the default value | `""`                                                                                  |
| `service.sessionAffinityConfig`                             | [Configuration](https://kubernetes.io/docs/reference/networking/virtual-ips/#session-stickiness-timeout) for ONLYOFFICE Docs service Session Affinity. Used if the `service.sessionAffinity` is set | `{}`                                                                 |
| `ingress.enabled`                                           | Enable the creation of an ingress for the ONLYOFFICE Docs                                                                                                                      | `false`                                                                                   |
| `ingress.annotations`                                       | Map of annotations to add to the Ingress. If set to, it takes priority over the `commonAnnotations`                                                                            | `nginx.ingress.kubernetes.io/proxy-body-size: 100m`                                       |
| `ingress.ingressClassName`                                  | Used to reference the IngressClass that should be used to implement this Ingress                                                                                               | `nginx`                                                                                   |
| `ingress.controllerName`                                    | Used to distinguish between controllers with the same IngressClassName but from different vendors                                                                              | `ingress-nginx`                                                                           |
| `ingress.host`                                              | Ingress hostname for the ONLYOFFICE Docs ingress                                                                                                                               | `""`                                                                                      |
| `ingress.tenants`                                           | Ingress hostnames if you need to use more than one name. For example, for multitenancy. If set to, it takes priority over the `ingress.host`. If `ingress.ssl.enabled` is set to `true`, it is assumed that the certificate for all specified domains is kept secret by `ingress.ssl.secret` | `[]` |
| `ingress.ssl.enabled`                                       | Enable ssl for the ONLYOFFICE Docs ingress                                                                                                                                     | `false`                                                                                   |
| `ingress.ssl.secret`                                        | Secret name for ssl to mount into the Ingress                                                                                                                                  | `tls`                                                                                     |
| `ingress.path`                                              | Specifies the path where ONLYOFFICE Docs will be available                                                                                                                     | `/`                                                                                       |
| `ingress.pathType`                                          | Specifies the path type for the ONLYOFFICE Docs ingress resource. Allowed values are `Exact`, `Prefix` or `ImplementationSpecific`                                             | `ImplementationSpecific`                                                                  |
| `ingress.letsencrypt.enabled`                               | Enabling certificate request creation in Let's Encrypt. Used if `ingress.enabled` is set to `true`                                                                             | `false`                                                                                   |
| `ingress.letsencrypt.clusterIssuerName`                     | ClusterIssuer Name                                                                                                                                                             | `letsencrypt-prod`                                                                        |
| `ingress.letsencrypt.email`                                 | Your email address used for ACME registration                                                                                                                                  | `""`                                                                                      |
| `ingress.letsencrypt.server`                                | The address of the Let's Encrypt server to which requests for certificates will be sent                                                                                        | `https://acme-v02.api.letsencrypt.org/directory`                                          |
| `ingress.letsencrypt.secretName`                            | Name of a secret used to store the ACME account private key                                                                                                                    | `letsencrypt-prod-private-key`                                                            |
| `openshift.route.enabled`                                   | Enable the creation of an OpenShift Route for the ONLYOFFICE Docs                                                                                                              | `false`                                                                                   |
| `openshift.route.annotations`                               | Map of annotations to add to the OpenShift Route. If set to, it takes priority over the `commonAnnotations`                                                                    | `{}`                                                                                      |
| `openshift.route.host`                                      | OpenShift Route hostname for the ONLYOFFICE Docs route                                                                                                                         | `""`                                                                                      |
| `openshift.route.path`                                      | Specifies the path where ONLYOFFICE Docs will be available                                                                                                                     | `/`                                                                                       |
| `openshift.route.wildcardPolicy`                            | The policy for handling wildcard subdomains in the OpenShift Route. Allowed values are `None`, `Subdomain`                                                                     | `None`                                                                                    |
| `grafana.enabled`                                           | Enable the installation of resources required for the visualization of metrics in Grafana                                                                                      | `false`                                                                                   |
| `grafana.namespace`                                         | The name of the namespace in which RBAC components and Grafana resources will be deployed. If not set, the name will be taken from `namespaceOverride` if set, or .Release.Namespace | `""`                                                                                |
| `grafana.ingress.enabled`                                   | Enable the creation of an ingress for the Grafana. Used if you set `grafana.enabled` to `true` and want to use Nginx Ingress to access Grafana                                 | `false`                                                                                   |
| `grafana.ingress.annotations`                               | Map of annotations to add to Grafana Ingress. If set to, it takes priority over the `commonAnnotations`                                                                        | `nginx.ingress.kubernetes.io/proxy-body-size: 100m`                                       |
| `grafana.dashboard.enabled`                                 | Enable the installation of ready-made Grafana dashboards. Used if you set `grafana.enabled` to `true`                                                                          | `false`                                                                                   |
| `podSecurityContext.enabled`                                | Enable security context for the pods                                                                                                                                           | `false`                                                                                   |
| `podSecurityContext.converter.fsGroup`                      | Defines the Group ID to which the owner and permissions for all files in volumes are changed when mounted in the Converter Pod                                                 | `101`                                                                                     |
| `podSecurityContext.docservice.fsGroup`                     | Defines the Group ID to which the owner and permissions for all files in volumes are changed when mounted in the Docservice Pod                                                | `101`                                                                                     |
| `podSecurityContext.jobs.fsGroup`                           | Defines the Group ID to which the owner and permissions for all files in volumes are changed when mounted in Pods created by Jobs                                              | `101`                                                                                     |
| `podSecurityContext.example.fsGroup`                        | Defines the Group ID to which the owner and permissions for all files in volumes are changed when mounted in the Example Pod                                                   | `1001`                                                                                    |
| `podSecurityContext.tests.fsGroup`                          | Defines the Group ID to which the owner and permissions for all files in volumes are changed when mounted in the Test Pod                                                      | `101`                                                                                     |
| `webProxy.enabled`                                          | Specify whether a Web proxy is used in your network to access the Pods of k8s cluster to the Internet                                                                          | `false`                                                                                   |
| `webProxy.http`                                             | Web Proxy address for `HTTP` traffic                                                                                                                                           | `http://proxy.example.com`                                                                |
| `webProxy.https`                                            | Web Proxy address for `HTTPS` traffic                                                                                                                                          | `https://proxy.example.com`                                                               |
| `webProxy.noProxy`                                          | Patterns for IP addresses or k8s services name or domain names that shouldn’t use the Web Proxy                                                                                | `localhost,127.0.0.1,docservice`                                                          |
| `privateCluster`                                            | Specify whether the k8s cluster is used in a private network without internet access                                                                                           | `false`                                                                                   |
| `upgrade.job.enabled`                                       | Enable the execution of job pre-upgrade before upgrading ONLYOFFICE Docs                                                                                                       | `true`                                                                                    |
| `upgrade.job.annotations`                                   | Defines annotations that will be additionally added to pre-upgrade Job. If set to, it takes priority over the `commonAnnotations`                                              | `{}`                                                                                      |
| `upgrade.job.podAnnotations`                                | Map of annotations to add to the pre-upgrade Pod                                                                                                                               | `{}`                                                                                      |
| `upgrade.job.customPodAntiAffinity`                         | Prohibiting the scheduling of pre-upgrade Job Pod relative to other Pods containing the specified labels on the same node                                                      | `{}`                                                                                      |
| `upgrade.job.podAffinity`                                   | Defines [Pod affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity) rules for pre-upgrade Job Pod scheduling by nodes relative to other Pods | `{}`                                                      |
| `upgrade.job.nodeAffinity`                                  | Defines [Node affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity) rules for pre-upgrade Job Pod scheduling by nodes                  | `{}`                                                                                  |
| `upgrade.job.nodeSelector`                                  | Node labels for pre-upgrade Job Pod assignment. If set to, it takes priority over the `nodeSelector`                                                                           | `{}`                                                                                      |
| `upgrade.job.tolerations`                                   | Tolerations for pre-upgrade Job Pod assignment. If set to, it takes priority over the `tolerations`                                                                            | `[]`                                                                                      |
| `upgrade.job.initContainers`                                | Defines containers that run before pre-upgrade container in the Pod                                                                                                            | `[]`                                                                                      |
| `upgrade.job.image.repository`                              | Job by upgrade image repository                                                                                                                                                | `onlyoffice/docs-utils`                                                                   |
| `upgrade.job.image.tag`                                     | Job by upgrade image tag                                                                                                                                                       | `9.0.3-1`                                                                                 |
| `upgrade.job.image.pullPolicy`                              | Job by upgrade image pull policy                                                                                                                                               | `IfNotPresent`                                                                            |
| `upgrade.job.containerSecurityContext.enabled`              | Enable security context for the pre-upgrade container                                                                                                                          | `false`                                                                                   |
| `upgrade.job.resources.requests`                            | The requested resources for the job pre-upgrade container                                                                                                                      | `{}`                                                                                      |
| `upgrade.job.resources.limits`                              | The resources limits for the job pre-upgrade container                                                                                                                         | `{}`                                                                                      |
| `upgrade.existingConfigmap.tblRemove.name`                  | The name of the existing ConfigMap that contains the sql file for deleting tables from the database                                                                            | `remove-db-scripts`                                                                       |
| `upgrade.existingConfigmap.tblRemove.keyName`               | The name of the sql file containing instructions for deleting tables from the database. Must be the same as the `key` name in `upgrade.existingConfigmap.tblRemove.name`       | `removetbl.sql`                                                                           |
| `upgrade.existingConfigmap.tblCreate.name`                  | The name of the existing ConfigMap that contains the sql file for craeting tables from the database                                                                            | `init-db-scripts`                                                                         |
| `upgrade.existingConfigmap.tblCreate.keyName`               | The name of the sql file containing instructions for creating tables from the database. Must be the same as the `key` name in `upgrade.existingConfigmap.tblCreate.name`       | `createdb.sql`                                                                            |
| `upgrade.existingConfigmap.dsStop`                          | The name of the existing ConfigMap that contains the ONLYOFFICE Docs upgrade script. If set, the four previous parameters are ignored. Must contain a key `stop.sh`            | `""`                                                                                      |
| `rollback.job.enabled`                                      | Enable the execution of job pre-rollback before rolling back ONLYOFFICE Docs                                                                                                   | `true`                                                                                    |
| `rollback.job.annotations`                                  | Defines annotations that will be additionally added to pre-rollback Job. If set to, it takes priority over the `commonAnnotations`                                             | `{}`                                                                                      |
| `rollback.job.podAnnotations`                               | Map of annotations to add to the pre-rollback Pod                                                                                                                              | `{}`                                                                                      |
| `rollback.job.customPodAntiAffinity`                        | Prohibiting the scheduling of pre-rollback Job Pod relative to other Pods containing the specified labels on the same node                                                     | `{}`                                                                                      |
| `rollback.job.podAffinity`                                  | Defines [Pod affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity) rules for pre-rollback Job Pod scheduling by nodes relative to other Pods | `{}`                                                     |
| `rollback.job.nodeAffinity`                                 | Defines [Node affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity) rules for pre-rollback Job Pod scheduling by nodes             | `{}`                                                                                      |
| `rollback.job.nodeSelector`                                 | Node labels for pre-rollback Job Pod assignment. If set to, it takes priority over the `nodeSelector`                                                                          | `{}`                                                                                      |
| `rollback.job.tolerations`                                  | Tolerations for pre-rollback Job Pod assignment. If set to, it takes priority over the `tolerations`                                                                           | `[]`                                                                                      |
| `rollback.job.initContainers`                               | Defines containers that run before pre-rollback container in the Pod                                                                                                           | `[]`                                                                                      |
| `rollback.job.image.repository`                             | Job by rollback image repository                                                                                                                                               | `onlyoffice/docs-utils`                                                                   |
| `rollback.job.image.tag`                                    | Job by rollback image tag                                                                                                                                                      | `9.0.3-1`                                                                                 |
| `rollback.job.image.pullPolicy`                             | Job by rollback image pull policy                                                                                                                                              | `IfNotPresent`                                                                            |
| `rollback.job.containerSecurityContext.enabled`             | Enable security context for the pre-rollback container                                                                                                                         | `false`                                                                                   |
| `rollback.job.resources.requests`                           | The requested resources for the job rollback container                                                                                                                         | `{}`                                                                                      |
| `rollback.job.resources.limits`                             | The resources limits for the job rollback container                                                                                                                            | `{}`                                                                                      |
| `rollback.existingConfigmap.tblRemove.name`                 | The name of the existing ConfigMap that contains the sql file for deleting tables from the database                                                                            | `remove-db-scripts`                                                                       |
| `rollback.existingConfigmap.tblRemove.keyName`              | The name of the sql file containing instructions for deleting tables from the database. Must be the same as the `key` name in `rollback.existingConfigmap.tblRemove.name`      | `removetbl.sql`                                                                           |
| `rollback.existingConfigmap.tblCreate.name`                 | The name of the existing ConfigMap that contains the sql file for craeting tables from the database                                                                            | `init-db-scripts`                                                                         |
| `rollback.existingConfigmap.tblCreate.keyName`              | The name of the sql file containing instructions for creating tables from the database. Must be the same as the `key` name in `rollback.existingConfigmap.tblCreate.name`      | `createdb.sql`                                                                            |
| `rollback.existingConfigmap.dsStop`                         | The name of the existing ConfigMap that contains the ONLYOFFICE Docs rollback script. If set, the four previous parameters are ignored. Must contain a key `stop.sh`           | `""`                                                                                      |
| `delete.job.enabled`                                        | Enable the execution of job pre-delete before deleting ONLYOFFICE Docs                                                                                                         | `true`                                                                                    |
| `delete.job.annotations`                                    | Defines annotations that will be additionally added to pre-delete Job. If set to, it takes priority over the `commonAnnotations`                                               | `{}`                                                                                      |
| `delete.job.podAnnotations`                                 | Map of annotations to add to the pre-delete Pod                                                                                                                                | `{}`                                                                                      |
| `delete.job.customPodAntiAffinity`                          | Prohibiting the scheduling of pre-delete Job Pod relative to other Pods containing the specified labels on the same node                                                       | `{}`                                                                                      |
| `delete.job.podAffinity`                                    | Defines [Pod affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity) rules for pre-delete Job Pod scheduling by nodes relative to other Pods | `{}`                                                       |
| `delete.job.nodeAffinity`                                   | Defines [Node affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity) rules for pre-delete Job Pod scheduling by nodes               | `{}`                                                                                      |
| `delete.job.nodeSelector`                                   | Node labels for pre-delete Job Pod assignment. If set to, it takes priority over the `nodeSelector`                                                                            | `{}`                                                                                      |
| `delete.job.tolerations`                                    | Tolerations for pre-delete Job Pod assignment. If set to, it takes priority over the `tolerations`                                                                             | `[]`                                                                                      |
| `delete.job.initContainers`                                 | Defines containers that run before pre-delete container in the Pod                                                                                                             | `[]`                                                                                      |
| `delete.job.image.repository`                               | Job by delete image repository                                                                                                                                                 | `onlyoffice/docs-utils`                                                                   |
| `delete.job.image.tag`                                      | Job by delete image tag                                                                                                                                                        | `9.0.3-1`                                                                                 |
| `delete.job.image.pullPolicy`                               | Job by delete image pull policy                                                                                                                                                | `IfNotPresent`                                                                            |
| `delete.job.containerSecurityContext.enabled`               | Enable security context for the pre-delete container                                                                                                                           | `false`                                                                                   |
| `delete.job.resources.requests`                             | The requested resources for the job delete container                                                                                                                           | `{}`                                                                                      |
| `delete.job.resources.limits`                               | The resources limits for the job delete container                                                                                                                              | `{}`                                                                                      |
| `delete.existingConfigmap.tblRemove.name`                   | The name of the existing ConfigMap that contains the sql file for deleting tables from the database                                                                            | `remove-db-scripts`                                                                       |
| `delete.existingConfigmap.tblRemove.keyName`                | The name of the sql file containing instructions for deleting tables from the database. Must be the same as the `key` name in `delete.existingConfigmap.tblRemove.name`        | `removetbl.sql`                                                                           |
| `delete.existingConfigmap.dsStop`                           | The name of the existing ConfigMap that contains the ONLYOFFICE Docs delete script. If set, the two previous parameters are ignored. Must contain a key `stop.sh`              | `""`                                                                                      |
| `install.job.enabled`                                       | Enable the execution of job pre-install before installing ONLYOFFICE Docs                                                                                                      | `true`                                                                                    |
| `install.job.annotations`                                   | Defines annotations that will be additionally added to pre-install Job. If set to, it takes priority over the `commonAnnotations`                                              | `{}`                                                                                      |
| `install.job.podAnnotations`                                | Map of annotations to add to the pre-install Pod                                                                                                                               | `{}`                                                                                      |
| `install.job.customPodAntiAffinity`                         | Prohibiting the scheduling of pre-install Job Pod relative to other Pods containing the specified labels on the same node                                                      | `{}`                                                                                      |
| `install.job.podAffinity`                                   | Defines [Pod affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity) rules for pre-install Job Pod scheduling by nodes relative to other Pods | `{}`                                                      |
| `install.job.nodeAffinity`                                  | Defines [Node affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity) rules for pre-install Job Pod scheduling by nodes              | `{}`                                                                                      |
| `install.job.nodeSelector`                                  | Node labels for pre-install Job Pod assignment. If set to, it takes priority over the `nodeSelector`                                                                           | `{}`                                                                                      |
| `install.job.tolerations`                                   | Tolerations for pre-install Job Pod assignment. If set to, it takes priority over the `tolerations`                                                                            | `[]`                                                                                      |
| `install.job.initContainers`                                | Defines containers that run before pre-install container in the Pod                                                                                                            | `[]`                                                                                      |
| `install.job.image.repository`                              | Job by pre-install ONLYOFFICE Docs image repository                                                                                                                            | `onlyoffice/docs-utils`                                                                   |
| `install.job.image.tag`                                     | Job by pre-install ONLYOFFICE Docs image tag                                                                                                                                   | `9.0.3-1`                                                                                 |
| `install.job.image.pullPolicy`                              | Job by pre-install ONLYOFFICE Docs image pull policy                                                                                                                           | `IfNotPresent`                                                                            |
| `install.job.containerSecurityContext.enabled`              | Enable security context for the pre-install container                                                                                                                          | `false`                                                                                   |
| `install.job.resources.requests`                            | The requested resources for the job pre-install container                                                                                                                      | `{}`                                                                                      |
| `install.job.resources.limits`                              | The resources limits for the job pre-install container                                                                                                                         | `{}`                                                                                      |
| `install.existingConfigmap.tblCreate.name`                  | The name of the existing ConfigMap that contains the sql file for craeting tables from the database                                                                            | `init-db-scripts`                                                                         |
| `install.existingConfigmap.tblCreate.keyName`               | The name of the sql file containing instructions for creating tables from the database. Must be the same as the `key` name in `install.existingConfigmap.tblCreate.name`       | `createdb.sql`                                                                            |
| `install.existingConfigmap.initdb`                          | The name of the existing ConfigMap that contains the initdb script. If set, the two previous parameters are ignored. Must contain a key `initdb.sh`                            | `""`                                                                                      |
| `clearCache.job.enabled`                                    | Enable the execution of job Clear Cache after upgrading ONLYOFFICE Docs. Job by Clear Cache has a `post-upgrade` hook executes after any resources have been upgraded in Kubernetes. He clears the Cache directory | `true`                                                |
| `clearCache.job.annotations`                                | Defines annotations that will be additionally added to Clear Cache Job. If set to, it takes priority over the `commonAnnotations`                                              | `{}`                                                                                      |
| `clearCache.job.podAnnotations`                             | Map of annotations to add to the Clear Cache Pod                                                                                                                               | `{}`                                                                                      |
| `clearCache.job.customPodAntiAffinity`                      | Prohibiting the scheduling of Clear Cache Job Pod relative to other Pods containing the specified labels on the same node                                                      | `{}`                                                                                      |
| `clearCache.job.podAffinity`                                | Defines [Pod affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity) rules for Clear Cache Job Pod scheduling by nodes relative to other Pods | `{}`                                                      |
| `clearCache.job.nodeAffinity`                               | Defines [Node affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity) rules for Clear Cache Job Pod scheduling by nodes              | `{}`                                                                                      |
| `clearCache.job.nodeSelector`                               | Node labels for Clear Cache Job Pod assignment. If set to, it takes priority over the `nodeSelector`                                                                           | `{}`                                                                                      |
| `clearCache.job.tolerations`                                | Tolerations for Clear Cache Job Pod assignment. If set to, it takes priority over the `tolerations`                                                                            | `[]`                                                                                      |
| `clearCache.job.initContainers`                             | Defines containers that run before Clear Cache container in the Pod                                                                                                            | `[]`                                                                                      |
| `clearCache.job.image.repository`                           | Job by Clear Cache ONLYOFFICE Docs image repository                                                                                                                            | `onlyoffice/docs-utils`                                                                   |
| `clearCache.job.image.tag`                                  | Job by Clear Cache ONLYOFFICE Docs image tag                                                                                                                                   | `9.0.3-1`                                                                                 |
| `clearCache.job.image.pullPolicy`                           | Job by Clear Cache ONLYOFFICE Docs image pull policy                                                                                                                           | `IfNotPresent`                                                                            |
| `clearCache.job.containerSecurityContext.enabled`           | Enable security context for the Clear Cache container                                                                                                                          | `false`                                                                                   |
| `clearCache.job.resources.requests`                         | The requested resources for the job Clear Cache container                                                                                                                      | `{}`                                                                                      |
| `clearCache.job.resources.limits`                           | The resources limits for the job Clear Cache container                                                                                                                         | `{}`                                                                                      |
| `clearCache.existingConfigmap.name`                         | The name of the existing ConfigMap that contains the clears the Cache directory custom script. If set, the default configmap will not be created                               | `""`                                                                                      |
| `clearCache.existingConfigmap.keyName`                      | The name of the script containing instructions for clears the Cache directory. Must be the same as the `key` name in `clearCache.existingConfigmap.name` if a custom script is used       | `clearCache.sh`                                                                |
| `grafanaDashboard.job.annotations`                          | Defines annotations that will be additionally added to Grafana Dashboard Job. If set to, it takes priority over the `commonAnnotations`                                        | `{}`                                                                                      |
| `grafanaDashboard.job.podAnnotations`                       | Map of annotations to add to the Grafana Dashboard Pod                                                                                                                         | `{}`                                                                                      |
| `grafanaDashboard.job.customPodAntiAffinity`                | Prohibiting the scheduling of Grafana Dashboard Job Pod relative to other Pods containing the specified labels on the same node                                                | `{}`                                                                                      |
| `grafanaDashboard.job.podAffinity`                          | Defines [Pod affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity) rules for Grafana Dashboard Job Pod scheduling by nodes relative to other Pods | `{}`                                                |
| `grafanaDashboard.job.nodeAffinity`                         | Defines [Node affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity) rules for Grafana Dashboard Job Pod scheduling by nodes        | `{}`                                                                                      |
| `grafanaDashboard.job.nodeSelector`                         | Node labels for Grafana Dashboard Job Pod assignment. If set to, it takes priority over the `nodeSelector`                                                                     | `{}`                                                                                      |
| `grafanaDashboard.job.tolerations`                          | Tolerations for Grafana Dashboard Job Pod assignment. If set to, it takes priority over the `tolerations`                                                                      | `[]`                                                                                      |
| `grafanaDashboard.job.initContainers`                       | Defines containers that run before Grafana Dashboard container in the Pod                                                                                                      | `[]`                                                                                      |
| `grafanaDashboard.job.image.repository`                     | Job by Grafana Dashboard ONLYOFFICE Docs image repository                                                                                                                      | `onlyoffice/docs-utils`                                                                   |
| `grafanaDashboard.job.image.tag`                            | Job by Grafana Dashboard ONLYOFFICE Docs image tag                                                                                                                             | `9.0.3-1`                                                                                 |
| `grafanaDashboard.job.image.pullPolicy`                     | Job by Grafana Dashboard ONLYOFFICE Docs image pull policy                                                                                                                     | `IfNotPresent`                                                                            |
| `grafanaDashboard.job.containerSecurityContext.enabled`     | Enable security context for the Grafana Dashboard container                                                                                                                    | `false`                                                                                   |
| `grafanaDashboard.job.resources.requests`                   | The requested resources for the job Grafana Dashboard container                                                                                                                | `{}`                                                                                      |
| `grafanaDashboard.job.resources.limits`                     | The resources limits for the job Grafana Dashboard container                                                                                                                   | `{}`                                                                                      |
| `wopiKeysGeneration.job.annotations`                        | Defines annotations that will be additionally added to Wopi Keys Generation Job. If set to, it takes priority over the `commonAnnotations`                                     | `{}`                                                                                      |
| `wopiKeysGeneration.job.podAnnotations`                     | Map of annotations to add to the Wopi Keys Generation Pod                                                                                                                      | `{}`                                                                                      |
| `wopiKeysGeneration.job.customPodAntiAffinity`              | Prohibiting the scheduling of Wopi Keys Generation Job Pod relative to other Pods containing the specified labels on the same node                                             | `{}`                                                                                      |
| `wopiKeysGeneration.job.podAffinity`                        | Defines [Pod affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity) rules for Wopi Keys Generation Job Pod scheduling by nodes relative to other Pods | `{}`                                                |
| `wopiKeysGeneration.job.nodeAffinity`                       | Defines [Node affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity) rules for Wopi Keys Generation Job Pod scheduling by nodes     | `{}`                                                                                      |
| `wopiKeysGeneration.job.nodeSelector`                       | Node labels for Wopi Keys Generation Job Pod assignment. If set to, it takes priority over the `nodeSelector`                                                                  | `{}`                                                                                      |
| `wopiKeysGeneration.job.tolerations`                        | Tolerations for Wopi Keys Generation Job Pod assignment. If set to, it takes priority over the `tolerations`                                                                   | `[]`                                                                                      |
| `wopiKeysGeneration.job.initContainers`                     | Defines containers that run before Wopi Keys Generation container in the Pod                                                                                                   | `[]`                                                                                      |
| `wopiKeysGeneration.job.image.repository`                   | Job by Wopi Keys Generation ONLYOFFICE Docs image repository                                                                                                                   | `onlyoffice/docs-utils`                                                                   |
| `wopiKeysGeneration.job.image.tag`                          | Job by Wopi Keys Generation ONLYOFFICE Docs image tag                                                                                                                          | `9.0.3-1`                                                                                 |
| `wopiKeysGeneration.job.image.pullPolicy`                   | Job by Wopi Keys Generation ONLYOFFICE Docs image pull policy                                                                                                                  | `IfNotPresent`                                                                            |
| `wopiKeysGeneration.job.containerSecurityContext.enabled`   | Enable security context for the Wopi Keys Generation container                                                                                                                 | `false`                                                                                   |
| `wopiKeysGeneration.job.resources.requests`                 | The requested resources for the job Wopi Keys Generation container                                                                                                             | `{}`                                                                                      |
| `wopiKeysGeneration.job.resources.limits`                   | The resources limits for the job Wopi Keys Generation container                                                                                                                | `{}`                                                                                      |
| `wopiKeysDeletion.job.enabled `                             | Enable the execution of Wopi Keys Deletion job before deleting ONLYOFFICE Docs. He removes the WOPI secrets generated automatically. It is executed if `wopi.enabled`, `wopi.keys.generation` and `wopiKeysDeletion.job.enabled` are set to `true` | `true`                |
| `wopiKeysDeletion.job.annotations`                          | Defines annotations that will be additionally added to Wopi Keys Deletion Job. If set to, it takes priority over the `commonAnnotations`                                       | `{}`                                                                                      |
| `wopiKeysDeletion.job.podAnnotations`                       | Map of annotations to add to the Wopi Keys Deletion Pod                                                                                                                        | `{}`                                                                                      |
| `wopiKeysDeletion.job.customPodAntiAffinity`                | Prohibiting the scheduling of Wopi Keys Deletion Job Pod relative to other Pods containing the specified labels on the same node                                               | `{}`                                                                                      |
| `wopiKeysDeletion.job.podAffinity`                          | Defines [Pod affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity) rules for Wopi Keys Deletion Job Pod scheduling by nodes relative to other Pods | `{}`                                               |
| `wopiKeysDeletion.job.nodeAffinity`                         | Defines [Node affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity) rules for Wopi Keys Deletion Job Pod scheduling by nodes       | `{}`                                                                                      |
| `wopiKeysDeletion.job.nodeSelector`                         | Node labels for Wopi Keys Deletion Job Pod assignment. If set to, it takes priority over the `nodeSelector`                                                                    | `{}`                                                                                      |
| `wopiKeysDeletion.job.tolerations`                          | Tolerations for Wopi Keys Deletion Job Pod assignment. If set to, it takes priority over the `tolerations`                                                                     | `[]`                                                                                      |
| `wopiKeysDeletion.job.initContainers`                       | Defines containers that run before Wopi Keys Deletion container in the Pod                                                                                                     | `[]`                                                                                      |
| `wopiKeysDeletion.job.image.repository`                     | Job by Wopi Keys Deletion ONLYOFFICE Docs image repository                                                                                                                     | `onlyoffice/docs-utils`                                                                   |
| `wopiKeysDeletion.job.image.tag`                            | Job by Wopi Keys Deletion ONLYOFFICE Docs image tag                                                                                                                            | `9.0.3-1`                                                                                 |
| `wopiKeysDeletion.job.image.pullPolicy`                     | Job by Wopi Keys Deletion ONLYOFFICE Docs image pull policy                                                                                                                    | `IfNotPresent`                                                                            |
| `wopiKeysDeletion.job.containerSecurityContext.enabled`     | Enable security context for the Wopi Keys Deletion container                                                                                                                   | `false`                                                                                   |
| `wopiKeysDeletion.job.resources.requests`                   | The requested resources for the job Wopi Keys Deletion container                                                                                                               | `{}`                                                                                      |
| `wopiKeysDeletion.job.resources.limits`                     | The resources limits for the job Wopi Keys Deletion container                                                                                                                  | `{}`                                                                                      |
| `tests.enabled`                                             | Enable the resources creation necessary for ONLYOFFICE Docs launch testing and connected dependencies availability testing. These resources will be used when running the `helm test` command | `true`                                                                     |
| `tests.annotations`                                         | Defines annotations that will be additionally added to Test Pod. If set to, it takes priority over the `commonAnnotations`                                                     | `{}`                                                                                      |
| `tests.customPodAntiAffinity`                               | Prohibiting the scheduling of Test Pod relative to other Pods containing the specified labels on the same node                                                                 | `{}`                                                                                      |
| `tests.podAffinity`                                         | Defines [Pod affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity) rules for Test Pod scheduling by nodes relative to other Pods | `{}`                                                                 |
| `tests.nodeAffinity`                                        | Defines [Node affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity) rules for Test Pod scheduling by nodes                         | `{}`                                                                                      |
| `tests.nodeSelector`                                        | Node labels for Test Pod assignment. If set to, it takes priority over the `nodeSelector`                                                                                      | `{}`                                                                                      |
| `tests.tolerations`                                         | Tolerations for Test Pod assignment. If set to, it takes priority over the `tolerations`                                                                                       | `[]`                                                                                      |
| `tests.initContainers`                                      | Defines containers that run before Test container in the Pod                                                                                                                   | `[]`                                                                                      |
| `tests.image.repository`                                    | Test container image name                                                                                                                                                      | `onlyoffice/docs-utils`                                                                   |
| `tests.image.tag`                                           | Test container image tag                                                                                                                                                       | `9.0.3-1`                                                                                 |
| `tests.image.pullPolicy`                                    | Test container image pull policy                                                                                                                                               | `IfNotPresent`                                                                            |
| `tests.containerSecurityContext.enabled`                    | Enable security context for the Test container                                                                                                                                 | `false`                                                                                   |
| `tests.resources.requests`                                  | The requested resources for the test container                                                                                                                                 | `{}`                                                                                      |
| `tests.resources.limits`                                    | The resources limits for the test container                                                                                                                                    | `{}`                                                                                      |

* *Note: The prefix `-de` is specified in the value of the image repository, which means solution type. Possible options:
  - `-de`. For commercial Developer Edition
  - `-ee`. For commercial Enterprise Edition

  The default value of this parameter refers to the ONLYOFFICE Document Server Developer Edition. To learn more about this edition and compare it with other editions, please see the comparison table on [this page](https://github.com/ONLYOFFICE/DocumentServer#onlyoffice-docs-editions).

Specify each parameter using the `--set key=value[,key=value]` argument to helm install. For example,

```bash
$ helm install documentserver onlyoffice/docs --set ingress.enabled=true,ingress.ssl.enabled=true,ingress.host=example.com
```

This command gives expose ONLYOFFICE Docs via HTTPS.

Alternatively, a YAML file that specifies the values for the parameters can be provided while installing the chart. For example,

```bash
$ helm install documentserver -f values.yaml onlyoffice/docs
```

> **Tip**: You can use the default [values.yaml](values.yaml)

### 5. Configuration and installation details

### 5.1 Example deployment (optional)

To deploy the example, set the `example.enabled` parameter to true:

```bash
$ helm install documentserver onlyoffice/docs --set example.enabled=true
```

### 5.2 Metrics deployment (optional)
To deploy metrics, set `metrics.enabled` to true:

```bash
$ helm install documentserver onlyoffice/docs --set metrics.enabled=true
```

If you want to use Grafana to visualize metrics, set `grafana.enabled` to `true`. If you want to use Nginx Ingress to access Grafana, set `grafana.ingress.enabled` to `true`:

```bash
$ helm install documentserver onlyoffice/docs --set grafana.enabled=true --set grafana.ingress.enabled=true
```

### 5.3 Expose ONLYOFFICE Docs

#### 5.3.1 Expose ONLYOFFICE Docs via Service (HTTP Only)

*You should skip step[#5.3.1](#531-expose-onlyoffice-docs-via-service-http-only) if you are going to expose ONLYOFFICE Docs via HTTPS*

This type of exposure has the least overheads of performance, it creates a loadbalancer to get access to ONLYOFFICE Docs.
Use this type of exposure if you use external TLS termination, and don't have another WEB application in the k8s cluster.

To expose ONLYOFFICE Docs via service, set the `service.type` parameter to LoadBalancer:

```bash
$ helm install documentserver onlyoffice/docs --set service.type=LoadBalancer,service.port=80

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


#### 5.3.2 Expose ONLYOFFICE Docs via Ingress

#### 5.3.2.1 Installing the Kubernetes Nginx Ingress Controller

To install the Nginx Ingress Controller to your cluster, run the following command:

```bash
$ helm install nginx-ingress ingress-nginx/ingress-nginx --set controller.publishService.enabled=true,controller.replicaCount=2
```

Note: To install Nginx Ingress with the same parameters and to enable exposing ingress-nginx metrics to be gathered by Prometheus, run the following command:

```bash
$ helm install nginx-ingress -f https://raw.githubusercontent.com/ONLYOFFICE/Kubernetes-Docs/master/sources/ingress_values.yaml ingress-nginx/ingress-nginx
```

See more detail about installing Nginx Ingress via Helm [here](https://github.com/kubernetes/ingress-nginx/tree/master/charts/ingress-nginx).

#### 5.3.2.2 Expose ONLYOFFICE Docs via HTTP

*You should skip step[5.3.2.2](#5322-expose-onlyoffice-docs-via-http) if you are going to expose ONLYOFFICE Docs via HTTPS*

This type of exposure has more overheads of performance compared with exposure via service, it also creates a loadbalancer to get access to ONLYOFFICE Docs. 
Use this type if you use external TLS termination and when you have several WEB applications in the k8s cluster. You can use the one set of ingress instances and the one loadbalancer for those. It can optimize the entry point performance and reduce your cluster payments, cause providers can charge a fee for each loadbalancer.

To expose ONLYOFFICE Docs via ingress HTTP, set the `ingress.enabled` parameter to true:

```bash
$ helm install documentserver onlyoffice/docs --set ingress.enabled=true
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

#### 5.3.2.3 Expose ONLYOFFICE Docs via HTTPS

This type of exposure allows you to enable internal TLS termination for ONLYOFFICE Docs.

Create the `tls` secret with an ssl certificate inside.

Put the ssl certificate and the private key into the `tls.crt` and `tls.key` files and then run:

```bash
$ kubectl create secret generic tls \
  --from-file=./tls.crt \
  --from-file=./tls.key
```

```bash
$ helm install documentserver onlyoffice/docs --set ingress.enabled=true,ingress.ssl.enabled=true,ingress.host=example.com

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

#### 5.3.2.4 Expose ONLYOFFICE Docs via HTTPS using the Let's Encrypt certificate
- Add Helm repositories:
  ```bash
  $ helm repo add jetstack https://charts.jetstack.io
  $ helm repo update
  ```
- Installing cert-manager
  ```bash
  $ helm install cert-manager --version v1.17.4 jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --set crds.enabled=true \
    --set crds.keep=false
  ```
Next, perform the installation or upgrade by setting the `ingress.enabled`, `ingress.ssl.enabled` and `ingress.letsencrypt.enabled` parameters to `true`. Also set your own values in the parameters `ingress.letsencrypt.email`, `ingress.host` or `ingress.tenants`(for example, `--set "ingress.tenants={tenant1.example.com,tenant2.example.com}"`) if you want to use multiple domain names.

#### 5.3.2.5 Expose ONLYOFFICE Docs on a virtual path
This type of exposure allows you to expose ONLYOFFICE Docs on a virtual path, for example, `http://your-domain-name/docs`.
To expose ONLYOFFICE Docs via ingress on a virtual path, set the `ingress.enabled`, `ingress.host` and `ingress.path` parameters.

```bash
$ helm install documentserver onlyoffice/docs --set ingress.enabled=true,ingress.host=your-domain-name,ingress.path=/docs
```

The list of supported ingress controllers for virtual path configuration:
* [Ingress NGINX by Kubernetes](https://github.com/kubernetes/ingress-nginx)
* [NGINX Ingress by NGINX](https://github.com/nginx/kubernetes-ingress/)
* [HAProxy Ingress by HAProxy](https://github.com/haproxytech/kubernetes-ingress/)

For virtual path configuration with `Ingress NGINX by Kubernetes`, append the pattern `(/|$)(.*)` to the `ingress.path`, for example, `/docs` becomes `/docs(/|$)(.*)`.

### 5.3.3 Expose ONLYOFFICE Docs via route in OpenShift
This type of exposure allows you to expose ONLYOFFICE Docs via route in OpenShift.
To expose ONLYOFFICE Docs via route, use these parameters: `openshift.route.enabled`, `openshift.route.host`, `openshift.route.path`.

```bash
$ helm install documentserver onlyoffice/docs --set openshift.route.enabled=true,openshift.route.host=your-domain-name,openshift.route.path=/docs
```

For tls termination, manually add certificates to the route via OpenShift web console.

### 6. Scale ONLYOFFICE Docs (optional)

*This step is optional. You can skip step [6](#6-scale-onlyoffice-docs-optional) entirely if you want to use default deployment settings.*

#### 6.1 Horizontal Pod Autoscaling

You can enable Autoscaling so that the number of replicas of `docservice` and `converter` deployments is calculated automatically based on the values and type of metrics.

For resource metrics, API metrics.k8s.io must be registered, which is generally provided by [metrics-server](https://github.com/kubernetes-sigs/metrics-server). It can be launched as a cluster add-on.

To use the target utilization value (`target.type==Utilization`), it is necessary that the values for `resources.requests` are specified in the deployment.

For more information about Horizontal Pod Autoscaling, see [here](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/).

To enable HPA for the `docservice` deployment, specify the `docservice.autoscaling.enabled=true` parameter. 
In this case, the `docservice.replicas` parameter is ignored and the number of replicas is controlled by HPA.

Similarly, to enable HPA for the `converter` deployment, specify the `converter.autoscaling.enabled=true` parameter. 
In this case, the `converter.replicas` parameter is ignored and the number of replicas is controlled by HPA.

With the `autoscaling.enabled` parameter enabled, by default Autoscaling will adjust the number of replicas based on the average percentage of CPU Utilization.
For other configurable Autoscaling parameters, see the [Parameters](#4-parameters) table.

#### 6.2 Manual scaling

The `docservice` and `converter` deployments consist of 2 pods each other by default.

To scale the `docservice` deployment, use the following command:

```bash
$ kubectl scale -n default deployment docservice --replicas=POD_COUNT
```

where `POD_COUNT` is a number of the `docservice` pods.

Do the same to scale the `converter` deployment:

```bash
$ kubectl scale -n default deployment converter --replicas=POD_COUNT
```

### 7. Update ONLYOFFICE Docs

It's necessary to set the parameters for updating. For example,

```bash
$ helm upgrade documentserver onlyoffice/docs \
  --set docservice.image.tag=[version]
```

  > **Note**: also need to specify the parameters that were specified during installation

Or modify the values.yaml file and run the command:

```bash
$ helm upgrade documentserver -f values.yaml onlyoffice/docs
```

Running the helm upgrade command runs a hook that shuts down the ONLYOFFICE Docs and cleans up the database. This is needed when updating the version of ONLYOFFICE Docs. The default hook execution time is 300s.
The execution time can be changed using --timeout [time], for example

```bash
$ helm upgrade documentserver -f values.yaml onlyoffice/docs --timeout 15m
```

Note: When upgrading ONLYOFFICE Docs in a private k8s cluster behind a Web proxy or with no internet access, see the [notes](#11-run-jobs-in-a-private-k8s-cluster-optional) below.

If you want to update any parameter other than the version of the ONLYOFFICE Docs, then run the `helm upgrade` command without `hooks`, for example:

```bash
$ helm upgrade documentserver onlyoffice/docs --set jwt.enabled=false --no-hooks
```

To rollback updates, run the following command:

```bash
$ helm rollback documentserver
```

Note: When rolling back ONLYOFFICE Docs in a private k8s cluster behind a Web proxy or with no internet access, see the [notes](#11-run-jobs-in-a-private-k8s-cluster-optional) below.

### 8. Shutdown ONLYOFFICE Docs (optional)

To perform the shutdown, run the following command:

```bash
$ kubectl apply -f https://raw.githubusercontent.com/ONLYOFFICE/Kubernetes-Docs/master/sources/shutdown-ds.yaml -n <NAMESPACE>
```

Where:
 - `<NAMESPACE>` - Namespace where ONLYOFFICE Docs is installed. If not specified, the default value will be used: `default`.

For example:

```bash
$ kubectl apply -f https://raw.githubusercontent.com/ONLYOFFICE/Kubernetes-Docs/master/sources/shutdown-ds.yaml -n onlyoffice
```

After successfully executing the Pod `shutdown-ds` that created the Job, delete this Job with the following command:

```bash
$ kubectl delete job shutdown-ds -n <NAMESPACE>
```

If after stopping ONLYOFFICE Docs you need to start it again then restart docservice and converter pods. For example, using the following command:

```bash
$ kubectl delete pod converter-*** docservice-*** -n <NAMESPACE>
```

### 9. Update ONLYOFFICE Docs license (optional)

In order to update the license, you need to perform the following steps:
 - Place the license.lic file containing the new key in some directory
 - Run the following commands:
```bash
$ kubectl delete secret [SECRET_LICENSE_NAME] -n <NAMESPACE>
$ kubectl create secret generic [SECRET_LICENSE_NAME] --from-file=path/to/license.lic -n <NAMESPACE>
```

- Where `SECRET_LICENSE_NAME` is the name of an existing secret with a license

 - Restart `docservice` and `converter` pods. For example, using the following command:
```bash
$ kubectl delete pod converter-*** docservice-*** -n <NAMESPACE>
```

### 10. ONLYOFFICE Docs installation test (optional)

You can test ONLYOFFICE Docs availability and access to connected dependencies by running the following command:

```bash
$ helm test documentserver -n <NAMESPACE>
```

The output should have the following line:

```bash
Phase: Succeeded
```

To view the log of the Pod running as a result of the `helm test` command, run the following command:

```bash
$ kubectl logs -f test-ds -n <NAMESPACE>
```

The ONLYOFFICE Docs availability check is considered a priority, so if it fails with an error, the test is considered to be failed.

After this, you can delete the `test-ds` Pod by running the following command:

```bash
$ kubectl delete pod test-ds -n <NAMESPACE>
```

Note: This testing is for informational purposes only and cannot guarantee 100% availability results.
It may be that even though all checks are completed successfully, an error occurs in the application.
In this case, more detailed information can be found in the application logs.

### 11. Run Jobs in a private k8s cluster (optional)

When running `Job` for installation, update, rollback and deletion, the container being launched needs Internet access to download the latest sql scripts.
If the access of containers to the external network is prohibited in your k8s cluster, then you can perform these Jobs by setting the `privateCluster=true` parameter and manually create a `ConfigMap` with the necessary sql scripts.

To do this, run the following commands:

If your cluster already has `remove-db-scripts` and `init-db-scripts` configmaps, then delete them:

```bash
$ kubectl delete cm remove-db-scripts init-db-scripts
```

Download the ONLYOFFICE Docs database scripts for database cleaning and database tables creating:

If PostgreSQL is selected as the database server:

```bash
$ wget -O removetbl.sql https://raw.githubusercontent.com/ONLYOFFICE/server/master/schema/postgresql/removetbl.sql
$ wget -O createdb.sql https://raw.githubusercontent.com/ONLYOFFICE/server/master/schema/postgresql/createdb.sql
```

If MySQL is selected as the database server:

```bash
$ wget -O removetbl.sql https://raw.githubusercontent.com/ONLYOFFICE/server/master/schema/mysql/removetbl.sql
$ wget -O createdb.sql https://raw.githubusercontent.com/ONLYOFFICE/server/master/schema/mysql/createdb.sql
```

Create a configmap from them:

```bash
$ kubectl create configmap remove-db-scripts --from-file=./removetbl.sql
$ kubectl create configmap init-db-scripts --from-file=./createdb.sql
```

Note: If you specified a different name for `ConfigMap` and for the file from which it is created, set the appropriate parameters for the corresponding Jobs:
 - `existingConfigmap.tblRemove.name` and `existingConfigmap.tblRemove.keyName` for scripts for database cleaning
 - `existingConfigmap.tblCreate.name` and `existingConfigmap.tblCreate.keyName` for scripts for database tables creating

Next, when executing the commands `helm install|upgrade|rollback|delete`, set the parameter `privateCluster=true`

  > **Note**: If it is possible to use a Web Proxy in your network to ensure the Pods containers have access to the Internet, then you can leave the parameter `privateCluster=false`, not manually create a configmaps with sql scripts and set the parameter `webProxy.enabled=true`, also setting the appropriate parameters for the Web Proxy.

### 12. Access to the info page (optional)

The access to `/info` page is limited by default.
In order to allow the access to it, you need to specify the IP addresses or subnets (that will be Proxy container clients in this case) using `proxy.infoAllowedIP` parameter.
Taking into consideration the specifics of Kubernetes net interaction it is possible to get the original IP of the user (being Proxy client) though it's not a standard scenario.
Generally the Pods / Nodes / Load Balancer addresses will actually be the clients, so these addresses are to be used.
In this case the access to the info page will be available to everyone.
You can further limit the access to the `info` page using Nginx [Basic Authentication](https://nginx.org/en/docs/http/ngx_http_auth_basic_module.html) which you can turn on by setting `proxy.infoAllowedUser` parameter value and by setting the password using `proxy.infoAllowedPassword` parameter, alternatively you can use the existing secret with password by setting its name with `proxy.infoAllowedExistingSecret` parameter.

## Using Grafana to visualize metrics (optional)

*This step is optional. You can skip this section if you don't want to install Grafana*

### 1. Deploy Grafana

Note: It is assumed that step [#6.2](#62-installing-prometheus) has already been completed.

#### 1.1 Deploy Grafana without installing ready-made dashboards

*You should skip step [#1.1](#11-deploy-grafana-without-installing-ready-made-dashboards) if you want to Deploy Grafana with the installation of ready-made dashboards*

To install Grafana to your cluster, run the following command:

```bash
$ helm install grafana bitnami/grafana \
  --set service.ports.grafana=80 \
  --set config.useGrafanaIniFile=true \
  --set config.grafanaIniConfigMap=grafana-ini \
  --set datasources.secretName=grafana-datasource
```

#### 1.2 Deploy Grafana with the installation of ready-made dashboards

#### 1.2.1 Installing ready-made Grafana dashboards

To install ready-made Grafana dashboards, set the `grafana.enabled` and `grafana.dashboard.enabled` parameters to `true`.
If ONLYOFFICE Docs is already installed you need to run the `helm upgrade documentserver onlyoffice/docs --set grafana.enabled=true --set grafana.dashboard.enabled=true` command or `helm upgrade documentserver -f ./values.yaml onlyoffice/docs` if the parameters are specified in the [values.yaml](values.yaml) file.
As a result, ready-made dashboards in the `JSON` format will be downloaded from the Grafana [website](https://grafana.com/grafana/dashboards),
the necessary edits will be made to them and configmap will be created from them. A dashboard will also be added to visualize metrics coming from the ONLYOFFICE Docs (it is assumed that step [#6](#6-deploy-statsd-exporter) has already been completed).

#### 1.2.2 Installing Grafana

To install Grafana to your cluster, run the following command:

```bash
$ helm install grafana bitnami/grafana \
  --set service.ports.grafana=80 \
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
  --set dashboardsConfigMaps[6].configMapName=dashboard-documentserver \
  --set dashboardsConfigMaps[6].fileName=dashboard-documentserver.json \
  --set dashboardsConfigMaps[7].configMapName=dashboard-cluster-resourses \
  --set dashboardsConfigMaps[7].fileName=dashboard-cluster-resourses.json
```

After executing this command, the following dashboards will be imported into Grafana:

  - Node Exporter
  - Deployment Statefulset Daemonset
  - Redis Dashboard for Prometheus Redis Exporter
  - RabbitMQ-Overview
  - PostgreSQL Database
  - NGINX Ingress controller
  - ONLYOFFICE Docs
  - Resource usage by Pods and Containers

Note: You can see the description of the ONLYOFFICE Docs metrics that are visualized in Grafana [here](https://github.com/ONLYOFFICE/Kubernetes-Docs/wiki/Document-Server-Metrics).

See more details about installing Grafana via Helm [here](https://github.com/bitnami/charts/tree/master/bitnami/grafana).

### 2 Access to Grafana via Ingress

Note: It is assumed that step [#5.3.2.1](#5321-installing-the-kubernetes-nginx-ingress-controller) has already been completed.

If ONLYOFFICE Docs was installed with the parameter `grafana.ingress.enabled` (step [#5.2](#52-metrics-deployment-optional)) then access to Grafana will be at: `http://INGRESS-ADDRESS/grafana/`

If Ingres was installed using a secure connection (step [#5.3.2.3](#5323-expose-onlyoffice-docs-via-https)), then access to Grafana will be at: `https://your-domain-name/grafana/`

### 3. View gathered metrics in Grafana

Go to the address `http(s)://your-domain-name/grafana/`

`Login - admin`

To get the password, run the following command:

```
$ kubectl get secret grafana-admin --namespace default -o jsonpath="{.data.GF_SECURITY_ADMIN_PASSWORD}" | base64 --decode
```

In the dashboard section, you will see the added dashboards that will display the metrics received from Prometheus.
