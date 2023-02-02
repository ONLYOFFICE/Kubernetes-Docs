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
    + [7.2 Specify parameters when installing DocumentServer](#72-specify-parameters-when-installing-documentserver)
  * [8. Add custom Fonts](#8-add-custom-fonts)
  * [9. Add Plugins](#9-add-plugins)
  * [10. Change interface themes](#10-change-interface-themes)
    + [10.1 Create a ConfigMap containing a json file](#101-create-a-configmap-containing-a-json-file)
    + [10.2 Specify parameters when installing DocumentServer](#102-specify-parameters-when-installing-documentserver)
- [Deploy ONLYOFFICE Docs](#deploy-onlyoffice-docs)
  * [1. Deploy the ONLYOFFICE Docs license](#1-deploy-the-onlyoffice-docs-license)
    + [1.1 Create secret](#11-create-secret)
    + [1.2 Specify parameters when installing DocumentServer](#12-specify-parameters-when-installing-documentserver)
  * [2. Deploy ONLYOFFICE Docs](#2-deploy-onlyoffice-docs)
  * [3. Uninstall ONLYOFFICE Docs](#3-uninstall-onlyoffice-docs)
  * [4. Parameters](#4-parameters)
  * [5. Configuration and installation details](#5-configuration-and-installation-details)
  * [5.1 Example deployment (optional)](#51-example-deployment-optional)
  * [5.2 Metrics deployment (optional)](#52-metrics-deployment-optional)
  * [5.3 Expose DocumentServer](#53-expose-documentserver)
    + [5.3.1 Expose DocumentServer via Service (HTTP Only)](#531-expose-documentserver-via-service-http-only)
    + [5.3.2 Expose DocumentServer via Ingress](#532-expose-documentserver-via-ingress)
    + [5.3.2.1 Installing the Kubernetes Nginx Ingress Controller](#5321-installing-the-kubernetes-nginx-ingress-controller)
    + [5.3.2.2 Expose DocumentServer via HTTP](#5322-expose-documentserver-via-http)
    + [5.3.2.3 Expose DocumentServer via HTTPS](#5323-expose-documentserver-via-https)
  * [6. Scale DocumentServer (optional)](#6-scale-documentserver-optional) 
      + [6.1 Horizontal Pod Autoscaling](#61-horizontal-pod-autoscaling)
      + [6.2 Manual scaling](#62-manual-scaling) 
  * [7. Update ONLYOFFICE Docs](#7-update-onlyoffice-docs)
  * [8. Shutdown ONLYOFFICE Docs (optional)](#8-shutdown-onlyoffice-docs-optional)
  * [9. Update ONLYOFFICE Docs license (optional)](#9-update-onlyoffice-docs-license-optional)
  * [10. Run Jobs in a private k8s cluster (optional)](#10-run-jobs-in-a-private-k8s-cluster-optional)
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

Note: When installing to an OpenShift cluster, you must apply the `SecurityContextConstraints` policy, which adds permission to run containers from a user whose `ID = 1001`.

To do this, run the following commands:
```
$ oc apply -f https://raw.githubusercontent.com/ONLYOFFICE/Kubernetes-Docs/master/sources/scc/helm-components.yaml
$ oc adm policy add-scc-to-group scc-helm-components system:authenticated
```

### 1. Add Helm repositories

```bash
$ helm repo add bitnami https://charts.bitnami.com/bitnami
$ helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
$ helm repo add nfs-server-provisioner https://kubernetes-sigs.github.io/nfs-ganesha-server-and-external-provisioner
$ helm repo add onlyoffice https://download.onlyoffice.com/charts/stable
$ helm repo update
```

### 2. Install Persistent Storage

Install NFS Server Provisioner

Note: When installing NFS Server Provisioner, Storage Classes - `NFS` is created. When installing to an OpenShift cluster, the user must have a role that allows you to create Storage Classes in the cluster. Read more [here](https://docs.openshift.com/container-platform/4.7/storage/dynamic-provisioning.html).

```bash
$ helm install nfs-server --version 1.5.0 nfs-server-provisioner/nfs-server-provisioner \
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
  --set metrics.enabled=false
```

Note: Set the `metrics.enabled=true` to enable exposing RabbitMQ metrics to be gathered by Prometheus.

See more details about installing RabbitMQ via Helm [here](https://github.com/bitnami/charts/tree/master/bitnami/rabbitmq#rabbitmq).

### 4. Deploy Redis

To install Redis to your cluster, run the following command:

```bash
$ helm install redis bitnami/redis \
  --set architecture=standalone \
  --set metrics.enabled=false
```

Note: Set the `metrics.enabled=true` to enable exposing Redis metrics to be gathered by Prometheus.

See more details about installing Redis via Helm [here](https://github.com/bitnami/charts/tree/master/bitnami/redis).

### 5. Deploy Database

As a database server, you can use PostgreSQL, MySQL or MariaDB

**If PostgreSQL is selected as the database server, then follow these steps**

To install PostgreSQL to your cluster, run the following command:

```
$ helm install postgresql bitnami/postgresql \
  --set auth.database=postgres \
  --set primary.persistence.size=PERSISTENT_SIZE \
  --set metrics.enabled=false
```

See more details about installing PostgreSQL via Helm [here](https://github.com/bitnami/charts/tree/master/bitnami/postgresql#postgresql).

**If MySQL is selected as the database server, then follow these steps**

To install MySQL to your cluster, run the following command:

```
$ helm install mysql bitnami/mysql \
  --set auth.database=onlyoffice \
  --set auth.username=onlyoffice \
  --set primary.persistence.size=PERSISTENT_SIZE \
  --set metrics.enabled=false
```

See more details about installing MySQL via Helm [here](https://github.com/bitnami/charts/tree/master/bitnami/mysql).

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

#### 7.2 Specify parameters when installing DocumentServer

When installing DocumentServer, specify the `extraConf.configMap=local-config` and `extraConf.filename=local.json` parameters

Note: If you need to add a configuration file after the DocumentServer is already installed, you need to execute step [7.1](#71-create-a-configmap-containing-a-json-file) 
and then run the `helm upgrade documentserver onlyoffice/docs --set extraConf.configMap=local-config --set extraConf.filename=local.json --no-hooks` command or 
`helm upgrade documentserver -f ./values.yaml onlyoffice/docs --no-hooks` if the parameters are specified in the `values.yaml` file.

### 8. Add custom Fonts

*This step is optional. You can skip step [#8](#8-add-custom-fonts) entirely if you don't need to add your fonts*

In order to add fonts to images, you need to rebuild the images. Refer to the relevant steps in [this](https://github.com/ONLYOFFICE/Docker-Docs#building-onlyoffice-docs) manual.
Then specify your images when installing the DocumentServer.

### 9. Add Plugins

*This step is optional. You can skip step [#9](#9-add-plugins) entirely if you don't need to add plugins*

In order to add plugins to images, you need to rebuild the images. Refer to the relevant steps in [this](https://github.com/ONLYOFFICE/Docker-Docs#building-onlyoffice-docs) manual.
Then specify your images when installing the DocumentServer.

### 10. Change interface themes

*This step is optional. You can skip step [#10](#10-change-interface-themes) entirely if you don't need to change the interface themes*

#### 10.1 Create a ConfigMap containing a json file

To create a ConfigMap with a json file that contains the interface themes, you need to run the following command:

```bash
$ kubectl create configmap custom-themes \
  --from-file=./custom-themes.json
```

Note: Instead of `custom-themes` and `custom-themes.json` you can use any other names.

#### 10.2 Specify parameters when installing DocumentServer

When installing DocumentServer, specify the `extraThemes.configMap=custom-themes` and `extraThemes.filename=custom-themes.json` parameters.

Note: If you need to add interface themes after the DocumentServer is already installed, you need to execute step [10.1](#101-create-a-configmap-containing-a-json-file)
and then run the `helm upgrade documentserver onlyoffice/docs --set extraThemes.configMap=custom-themes --set extraThemes.filename=custom-themes.json --no-hooks` command or
`helm upgrade documentserver -f ./values.yaml onlyoffice/docs --no-hooks` if the parameters are specified in the `values.yaml` file.

## Deploy ONLYOFFICE Docs

Note: When installing to an OpenShift cluster, you must apply the `SecurityContextConstraints` policy, which adds permission to run containers from a user whose `ID = 101`.

To do this, run the following commands:
```
$ oc apply -f https://raw.githubusercontent.com/ONLYOFFICE/Kubernetes-Docs/master/sources/scc/docs-components.yaml
$ oc adm policy add-scc-to-group scc-docs-components system:authenticated
```
Also, you must set the `podSecurityContext.enabled` parameter to `true`:
```
$ helm install documentserver onlyoffice/docs --set podSecurityContext.enabled=true
```

### 1. Deploy the ONLYOFFICE Docs license

#### 1.1. Create secret

If you have a valid ONLYOFFICE Docs license, create a secret `license` from the file:

```
$ kubectl create secret generic license --from-file=path/to/license.lic
```

Note: The source license file name should be 'license.lic' because this name would be used as a field in the created secret.

#### 1.2. Specify parameters when installing DocumentServer

When installing DocumentServer, specify the `license.existingSecret=license` parameter.

```
$ helm install documentserver onlyoffice/docs --set license.existingSecret=license
```

Note: If you need to add license after the DocumentServer is already installed, you need to execute step [1.1](#11-create-secret) and then run the `helm upgrade documentserver onlyoffice/docs --set license.existingSecret=license --no-hooks` command or `helm upgrade documentserver -f ./values.yaml onlyoffice/docs --no-hooks` if the parameters are specified in the `values.yaml` file.

### 2. Deploy ONLYOFFICE Docs

To deploy DocumentServer with the release name `documentserver`:

```bash
$ helm install documentserver onlyoffice/docs
```

The command deploys DocumentServer on the Kubernetes cluster in the default configuration. The [Parameters](#4-parameters) section lists the parameters that can be configured during installation.

Note: When installing ONLYOFFICE Docs in a private k8s cluster behind a Web proxy or with no internet access, see the [notes](#10-run-jobs-in-a-private-k8s-cluster-optional) below.

### 3. Uninstall ONLYOFFICE Docs

To uninstall/delete the `documentserver` deployment:

```bash
$ helm delete documentserver
```

Executing the `helm delete` command launches hooks, which perform some preparatory actions before completely deleting the documentserver, which include stopping the server, cleaning up the used PVC and database tables.
The default hook execution time is 300s. The execution time can be changed using `--timeout [time]`, for example:

```bash
$ helm delete documentserver --timeout 25m
```

Note: When deleting ONLYOFFICE Docs in a private k8s cluster behind a Web proxy or with no internet access, see the [notes](#10-run-jobs-in-a-private-k8s-cluster-optional) below.

If you want to delete the documentserver without any preparatory actions, run the following command:

```bash
$ helm delete documentserver --no-hooks
```

The `helm delete` command removes all the Kubernetes components associated with the chart and deletes the release.

### 4. Parameters

| Parameter                                                   | Description                                                                                                                                                                    | Default                                                                                   |
|-------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| `connections.dbType`                                        | The database type. Possible values are `postgres`, `mariadb` or `mysql`                                                                                                        | `postgres`                                                                                |
| `connections.dbHost`                                        | The IP address or the name of the Database host                                                                                                                                | `postgresql`                                                                              |
| `connections.dbUser`                                        | Database user                                                                                                                                                                  | `postgres`                                                                                |
| `connections.dbPort`                                        | Database server port number                                                                                                                                                    | `5432`                                                                                    |
| `connections.dbName`                                        | Name of the Database database the application will be connected with                                                                                                           | `postgres`                                                                                |
| `connections.dbPassword`                                    | Database user password. If set to, it takes priority over the `connections.dbExistingSecret`                                                                                   | `""`                                                                                      |
| `connections.dbSecretKeyName`                               | The name of the key that contains the Database user password                                                                                                                   | `postgres-password`                                                                       |
| `connections.dbExistingSecret`                              | Name of existing secret to use for Database passwords. Must contain the key specified in `connections.dbSecretKeyName`                                                         | `postgresql`                                                                              |
| `connections.redistHost`                                    | The IP address or the name of the Redis host                                                                                                                                   | `redis-master`                                                                            |
| `connections.redisPort`                                     | The Redis server port number                                                                                                                                                   | `6379`                                                                                    |
| `connections.redisUser`                                     | The Redis [user](https://redis.io/docs/management/security/acl/) name. The value in this parameter overrides the value set in the `options` object in `local.json` if you add custom configuration file | `default`                                                        |
| `connections.redisDBNum`                                    | Number of the redis logical database to be [selected](https://redis.io/commands/select/). The value in this parameter overrides the value set in the `options` object in `local.json` if you add custom configuration file | `0`                                           |
| `connections.redisPassword`                                 | The password set for the Redis account. If set to, it takes priority over the `connections.redisExistingSecret`. The value in this parameter overrides the value set in the `options` object in `local.json` if you add custom configuration file | `""`                   |
| `connections.redisSecretKeyName`                            | The name of the key that contains the Redis user password                                                                                                                      | `redis-password`                                                                          |
| `connections.redisExistingSecret`                           | Name of existing secret to use for Redis passwords. Must contain the key specified in `connections.redisSecretKeyName`. The password from this secret overrides password set in the `options` object in `local.json` | `redis`                                             |
| `connections.redisNoPass`                                   | Defines whether to use a Redis auth without a password. If the connection to Redis server does not require a password, set the value to `true`                                 | `false`                                                                                   |
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
| `persistence.storageClass`                                  | PVC Storage Class for ONLYOFFICE Docs data volume                                                                                                                              | `nfs`                                                                                     |
| `persistence.size`                                          | PVC Storage Request for ONLYOFFICE Docs volume                                                                                                                                 | `8Gi`                                                                                     |
| `namespaceOverride`                                         | The name of the namespace in which Onlyoffice Docs will be deployed. If not set, the name will be taken from `.Release.Namespace`                                              | `""`                                                                                      |
| `commonLabels`                                              | Defines labels that will be additionally added to all the deployed resources. You can also use `tpl` as the value for the key                                                  | `{}`                                                                                      |
| `serviceAccount.create`                                     | Enable ServiceAccount creation                                                                                                                                                 | `false`                                                                                   |
| `serviceAccount.name`                                       | Name of the ServiceAccount to be used. If not set and `serviceAccount.create` is `true` the name will be taken from `.Release.Name` or `serviceAccount.create` is `false` the name will be "default" | `""`                                                                |
| `serviceAccount.annotations`                                | Map of annotations to add to the ServiceAccount                                                                                                                                | `{}`                                                                                      |
| `serviceAccount.automountServiceAccountToken`               | Enable auto mount of ServiceAccountToken on the serviceAccount created. Used only if `serviceAccount.create` is `true`                                                         | `true`                                                                                    |
| `license.existingSecret`                                    | Name of the existing secret that contains the license. Must contain the key `license.lic`                                                                                      | `""`                                                                                      |
| `license.existingClaim`                                     | Name of the existing PVC in which the license is stored. Must contain the file `license.lic`                                                                                   | `""`                                                                                      |
| `log.level`                                                 | Defines the type and severity of a logged event. Possible values are `ALL`, `TRACE`, `DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL`, `MARK`, `OFF`                                  | `WARN`                                                                                    |
| `log.type`                                                  | Defines the format of a logged event. Possible values are `pattern`, `json`, `basic`, `coloured`, `messagePassThrough`, `dummy`                                                | `pattern`                                                                                 |
| `log.pattern`                                               | Defines the log [pattern](https://github.com/log4js-node/log4js-node/blob/master/docs/layouts.md#pattern-format) if `log.type=pattern`                                         | `[%d] [%p] %c - %.10000m`                                                                 |
| `wopi.enabled`                                              | Defines if `WOPI` is enabled. If the parameter is enabled, then caching attributes for the mounted directory (`PVC`) should be disabled for the client                         | `false`                                                                                   |
| `metrics.enabled`                                           | Specifies the enabling StatsD for ONLYOFFICE Docs                                                                                                                              | `false`                                                                                   |
| `metrics.host`                                              | Defines StatsD listening host                                                                                                                                                  | `statsd-exporter-prometheus-statsd-exporter`                                              |
| `metrics.port`                                              | Defines StatsD listening port                                                                                                                                                  | `8125`                                                                                    |
| `metrics.prefix`                                            | Defines StatsD metrics prefix for backend services                                                                                                                             | `ds.`                                                                                     |
| `example.enabled`                                           | Enables the installation of Example                                                                                                                                            | `false`                                                                                   |
| `example.podAnnotations`                                    | Map of annotations to add to the example pod                                                                                                                                   | `rollme: "{{ randAlphaNum 5 \| quote }}"`                                                 |
| `example.updateStrategy.type`                               | Example StatefulSet update strategy type                                                                                                                                       | `RollingUpdate`                                                                           |
| `example.podAffinity`                                       | Defines [Pod affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity) rules for Example Pod scheduling by nodes relative to other Pods | `{}`                                                              |
| `example.nodeAffinity`                                      | Defines [Node affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity) rules for Example Pod scheduling by nodes                      | `{}`                                                                                      |
| `example.image.repository`                                  | Example container image name                                                                                                                                                   | `onlyoffice/docs-example`                                                                 |
| `example.image.tag`                                         | Example container image tag                                                                                                                                                    | `7.3.0-1`                                                                                 |
| `example.image.pullPolicy`                                  | Example container image pull policy                                                                                                                                            | `IfNotPresent`                                                                            |
| `example.dsUrl`                                             | Documentserver external address. It should be changed only if it is necessary to check the operation of the conversion in Example (e.g. http://\<documentserver-address\>/)    | `/`                                                                                       |
| `example.resources.requests`                                | The requested resources for the Example container                                                                                                                              | `{}`                                                                                      |
| `example.resources.limits`                                  | The resources limits for the Example container                                                                                                                                 | `{}`                                                                                      |
| `extraConf.configMap`                                       | The name of the ConfigMap containing the json file that override the default values                                                                                            | `""`                                                                                      |
| `extraConf.filename`                                        | The name of the json file that contains custom values. Must be the same as the `key` name in `extraConf.ConfigMap`                                                             | `local.json`                                                                              |
| `extraThemes.configMap`                                     | The name of the ConfigMap containing the json file that contains the interface themes                                                                                          | `""`                                                                                      |
| `extraThemes.filename`                                      | The name of the json file that contains custom interface themes. Must be the same as the `key` name in `extraThemes.configMap`                                                 | `custom-themes.json`                                                                      |
| `podAntiAffinity.type`                                      | Types of Pod antiaffinity. Allowed values: `soft` or `hard`                                                                                                                    | `soft`                                                                                    |
| `podAntiAffinity.topologyKey`                               | Node label key to match                                                                                                                                                        | `kubernetes.io/hostname`                                                                  |
| `podAntiAffinity.weight`                                    | Priority when selecting node. It is in the range from 1 to 100                                                                                                                 | `100`                                                                                     |
| `nodeSelector`                                              | Node labels for pods assignment                                                                                                                                                | `{}`                                                                                      |
| `tolerations`                                               | Tolerations for pods assignment                                                                                                                                                | `[]`                                                                                      |
| `docservice.podAnnotations`                                 | Map of annotations to add to the Docservice deployment pods                                                                                                                    | `rollme: "{{ randAlphaNum 5 \| quote }}"`                                                 |
| `docservice.replicas`                                       | Docservice replicas quantity. If the `docservice.autoscaling.enabled` parameter is enabled, it is ignored                                                                      | `2`                                                                                       |
| `docservice.updateStrategy.type`                            | Docservice deployment update strategy type                                                                                                                                     | `Recreate`                                                                                |
| `docservice.podAffinity`                                    | Defines [Pod affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity) rules for Docservice Pods scheduling by nodes relative to other Pods | `{}`                                                          |
| `docservice.nodeAffinity`                                   | Defines [Node affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity) rules for Docservice Pods scheduling by nodes                  | `{}`                                                                                      |
| `docservice.initContainers`                                 | Defines containers that run before docservice and proxy containers in the Docservice deployment pod. For example, a container that changes the owner of the PersistentVolume   | `[]`                                                                                      |
| `docservice.image.repository`                               | Docservice container image repository*                                                                                                                                         | `onlyoffice/docs-docservice-de`                                                           |
| `docservice.image.tag`                                      | Docservice container image tag                                                                                                                                                 | `7.3.0-1`                                                                                 |
| `docservice.image.pullPolicy`                               | Docservice container image pull policy                                                                                                                                         | `IfNotPresent`                                                                            |
| `docservice.resources.requests`                             | The requested resources for the Docservice container                                                                                                                           | `{}`                                                                                      |
| `docservice.resources.limits`                               | The resources limits for the Docservice container                                                                                                                              | `{}`                                                                                      |
| `docservice.readinessProbe.enabled`                         | Enable readinessProbe for Docservice container                                                                                                                                 | `true`                                                                                    |
| `docservice.livenessProbe.enabled`                          | Enable livenessProbe for Docservice container                                                                                                                                  | `true`                                                                                    |
| `docservice.startupProbe.enabled`                           | Enable startupProbe for Docservice container                                                                                                                                   | `true`                                                                                    |
| `docservice.autoscaling.enabled`                            | Enable Docservice deployment autoscaling                                                                                                                                       | `false`                                                                                   |
| `docservice.autoscaling.minReplicas`                        | Docservice deployment autoscaling minimum number of replicas                                                                                                                   | `2`                                                                                       |
| `docservice.autoscaling.maxReplicas`                        | Docservice deployment autoscaling maximum number of replicas                                                                                                                   | `4`                                                                                       |
| `docservice.autoscaling.targetCPU.enabled`                  | Enable autoscaling of Docservice deployment by CPU usage percentage                                                                                                            | `true`                                                                                    |
| `docservice.autoscaling.targetCPU.utilizationPercentage`    | Docservice deployment autoscaling target CPU percentage                                                                                                                        | `70`                                                                                      |
| `docservice.autoscaling.targetMemory.enabled`               | Enable autoscaling of Docservice deployment by memory usage percentage                                                                                                         | `false`                                                                                   |
| `docservice.autoscaling.targetMemory.utilizationPercentage` | Docservice deployment autoscaling target memory percentage                                                                                                                     | `70`                                                                                      |
| `docservice.autoscaling.customMetricsType`                  | Custom, additional or external autoscaling metrics for the Docservice deployment                                                                                               | `[]`                                                                                      |
| `docservice.autoscaling.behavior`                           | Configuring Docservice deployment scaling behavior policies for the `scaleDown` and `scaleUp` fields                                                                           | `{}`                                                                                      |
| `proxy.gzipProxied`                                         | Defines the nginx config [gzip_proxied](https://nginx.org/en/docs/http/ngx_http_gzip_module.html#gzip_proxied) directive                                                       | `off`                                                                                     |
| `proxy.secureLinkSecret`                                    | Defines secret for the nginx config directive [secure_link_md5](https://nginx.org/en/docs/http/ngx_http_secure_link_module.html#secure_link_md5)                               | `verysecretstring`                                                                        |
| `proxy.infoAllowedIP`                                       | Defines ip addresses for accessing the info page                                                                                                                               | `[]`                                                                                      |
| `proxy.welcomePage.enabled`                                 | Defines whether the welcome page will be displayed                                                                                                                             | `true`                                                                                    |
| `proxy.image.repository`                                    | Docservice Proxy container image repository*                                                                                                                                   | `onlyoffice/docs-proxy-de`                                                                |
| `proxy.image.tag`                                           | Docservice Proxy container image tag                                                                                                                                           | `7.3.0-1`                                                                                 |
| `proxy.image.pullPolicy`                                    | Docservice Proxy container image pull policy                                                                                                                                   | `IfNotPresent`                                                                            |
| `proxy.resources.requests`                                  | The requested resources for the Proxy container                                                                                                                                | `{}`                                                                                      |
| `proxy.resources.limits`                                    | The resources limits for the Proxy container                                                                                                                                   | `{}`                                                                                      |
| `proxy.readinessProbe.enabled`                              | Enable readinessProbe for  Proxy container                                                                                                                                     | `true`                                                                                    |
| `proxy.livenessProbe.enabled`                               | Enable livenessProbe for Proxy container                                                                                                                                       | `true`                                                                                    |
| `proxy.startupProbe.enabled`                                | Enable startupProbe for Proxy container                                                                                                                                        | `true`                                                                                    |
| `converter.podAnnotations`                                  | Map of annotations to add to the Converter deployment pods                                                                                                                     | `rollme: "{{ randAlphaNum 5 \| quote }}"`                                                 |
| `converter.replicas`                                        | Converter replicas quantity. If the `converter.autoscaling.enabled` parameter is enabled, it is ignored                                                                        | `2`                                                                                       |
| `converter.updateStrategy.type`                             | Converter deployment update strategy type                                                                                                                                      | `RollingUpdate`                                                                           |
| `converter.updateStrategy.rollingUpdate.maxUnavailable`     | Maximum number of Converter Pods unavailable during the update process. Used only when `converter.updateStrategy.type=RollingUpdate`                                           | `25%`                                                                                     |
| `converter.updateStrategy.rollingUpdate.maxSurge`           | Maximum number of Converter Pods created over the desired number of Pods. Used only when `converter.updateStrategy.type=RollingUpdate`                                         | `25%`                                                                                     |
| `converter.podAffinity`                                     | Defines [Pod affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity) rules for Converter Pods scheduling by nodes relative to other Pods | `{}`                                                           |
| `converter.nodeAffinity`                                    | Defines [Node affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity) rules for Converter Pods scheduling by nodes                   | `{}`                                                                                      |
| `converter.initContainers`                                  | Defines containers that run before docservice and proxy containers in the Docservice deployment pod. For example, a container that changes the owner of the PersistentVolume   | `[]`                                                                                      |
| `converter.image.repository`                                | Converter container image repository*                                                                                                                                          | `onlyoffice/docs-converter-de`                                                            |
| `converter.image.tag`                                       | Converter container image tag                                                                                                                                                  | `7.3.0-1`                                                                                 |
| `converter.image.pullPolicy`                                | Converter container image pull policy                                                                                                                                          | `IfNotPresent`                                                                            |
| `converter.resources.requests`                              | The requested resources for the Converter container                                                                                                                            | `{}`                                                                                      |
| `converter.resources.limits`                                | The resources limits for the Converter container                                                                                                                               | `{}`                                                                                      |
| `converter.autoscaling.enabled`                             | Enable Converter deployment autoscaling                                                                                                                                        | `false`                                                                                   |
| `converter.autoscaling.minReplicas`                         | Converter deployment autoscaling minimum number of replicas                                                                                                                    | `2`                                                                                       |
| `converter.autoscaling.maxReplicas`                         | Converter deployment autoscaling maximum number of replicas                                                                                                                    | `16`                                                                                      |
| `converter.autoscaling.targetCPU.enabled`                   | Enable autoscaling of converter deployment by CPU usage percentage                                                                                                             | `true`                                                                                    |
| `converter.autoscaling.targetCPU.utilizationPercentage`     | Converter deployment autoscaling target CPU percentage                                                                                                                         | `70`                                                                                      |
| `converter.autoscaling.targetMemory.enabled`                | Enable autoscaling of Converter deployment by memory usage percentage                                                                                                          | `false`                                                                                   |
| `converter.autoscaling.targetMemory.utilizationPercentage`  | Converter deployment autoscaling target memory percentage                                                                                                                     | `70`                                                                                       |
| `converter.autoscaling.customMetricsType`                   | Custom, additional or external autoscaling metrics for the Converter deployment                                                                                                | `[]`                                                                                      |
| `converter.autoscaling.behavior`                            | Configuring Converter deployment scaling behavior policies for the `scaleDown` and `scaleUp` fields                                                                            | `{}`                                                                                      |
| `jwt.enabled`                                               | Specifies the enabling the JSON Web Token validation by the ONLYOFFICE Docs. Common for inbox and outbox requests                                                              | `true`                                                                                    |
| `jwt.secret`                                                | Defines the secret key to validate the JSON Web Token in the request to the ONLYOFFICE Docs. Common for inbox and outbox requests                                              | `MYSECRET`                                                                                |
| `jwt.header`                                                | Defines the http header that will be used to send the JSON Web Token. Common for inbox and outbox requests                                                                     | `Authorization`                                                                           |
| `jwt.inBody`                                                | Specifies the enabling the token validation in the request body to the ONLYOFFICE Docs                                                                                         | `false`                                                                                   |
| `jwt.inbox`                                                 | JSON Web Token validation parameters for inbox requests only. If not specified, the values of the parameters of the common `jwt` are used                                      | `{}`                                                                                      |
| `jwt.outbox`                                                | JSON Web Token validation parameters for outbox requests only. If not specified, the values of the parameters of the common `jwt` are used                                     | `{}`                                                                                      |
| `jwt.existingSecret`                                        | The name of an existing secret containing variables for jwt. If not specified, a secret named `jwt` will be created                                                            | `""`                                                                                      |
| `service.existing`                                          | The name of an existing service for ONLYOFFICE Docs. If not specified, a service named `documentserver` will be created                                                        | `""`                                                                                      |
| `service.annotations`                                       | Map of annotations to add to the ONLYOFFICE Docs service                                                                                                                       | `{}`                                                                                      |
| `service.type`                                              | ONLYOFFICE Docs service type                                                                                                                                                   | `ClusterIP`                                                                               |
| `service.port`                                              | ONLYOFFICE Docs service port                                                                                                                                                   | `8888`                                                                                    |
| `service.sessionAffinity`                                   | [Session Affinity](https://kubernetes.io/docs/reference/networking/virtual-ips/#session-affinity) for ONLYOFFICE Docs service. If not set, `None` will be set as the default value | `""`                                                                                  |
| `service.sessionAffinityConfig`                             | [Configuration](https://kubernetes.io/docs/reference/networking/virtual-ips/#session-stickiness-timeout) for ONLYOFFICE Docs service Session Affinity. Used if the `service.sessionAffinity` is set | `{}`                                                                 |
| `ingress.enabled`                                           | Enable the creation of an ingress for the ONLYOFFICE Docs                                                                                                                      | `false`                                                                                   |
| `ingress.annotations`                                       | Map of annotations to add to the Ingress                                                                                                                                       | `kubernetes.io/ingress.class: nginx`, `nginx.ingress.kubernetes.io/proxy-body-size: 100m` |
| `ingress.host`                                              | Ingress hostname for the ONLYOFFICE Docs ingress                                                                                                                               | `""`                                                                                      |
| `ingress.ssl.enabled`                                       | Enable ssl for the ONLYOFFICE Docs ingress                                                                                                                                     | `false`                                                                                   |
| `ingress.ssl.secret`                                        | Secret name for ssl to mount into the Ingress                                                                                                                                  | `tls`                                                                                     |
| `grafana.enabled`                                           | Enable the installation of resources required for the visualization of metrics in Grafana                                                                                      | `false`                                                                                   |
| `grafana.namespace`                                         | The name of the namespace in which RBAC components and Grafana resources will be deployed. If not set, the name will be taken from `namespaceOverride` if set, or .Release.Namespace | `""`                                                                                |
| `grafana.ingress.enabled`                                   | Enable the creation of an ingress for the Grafana. Used if you set `grafana.enabled` to `true` and want to use Nginx Ingress to access Grafana                                 | `false`                                                                                   |
| `grafana.dashboard.enabled`                                 | Enable the installation of ready-made Grafana dashboards. Used if you set `grafana.enabled` to `true`                                                                          | `false`                                                                                   |
| `podSecurityContext.enabled`                                | Enable security context for the pods                                                                                                                                           | `false`                                                                                   |
| `podSecurityContext.converter.runAsUser`                    | User ID for the Converter pods                                                                                                                                                 | `101`                                                                                     |
| `podSecurityContext.converter.runAsGroup`                   | Group ID for the Converter pods                                                                                                                                                | `101`                                                                                     |
| `podSecurityContext.docservice.runAsUser`                   | User ID for the Docservice pods                                                                                                                                                | `101`                                                                                     |
| `podSecurityContext.docservice.runAsGroup`                  | Group ID for the Docservice pods                                                                                                                                               | `101`                                                                                     |
| `podSecurityContext.jobs.runAsUser`                         | User ID for pods created by jobs                                                                                                                                               | `101`                                                                                     |
| `podSecurityContext.jobs.runAsGroup`                        | Group ID for pods created by jobs                                                                                                                                              | `101`                                                                                     |
| `podSecurityContext.example.runAsUser`                      | User ID for the Example pod                                                                                                                                                    | `1001`                                                                                    |
| `podSecurityContext.example.runAsGroup`                     | Group ID for the Example pod                                                                                                                                                   | `1001`                                                                                    |
| `webProxy.enabled`                                          | Specify whether a Web proxy is used in your network to access the Pods of k8s cluster to the Internet                                                                          | `false`                                                                                   |
| `webProxy.http`                                             | Web Proxy address for `HTTP` traffic                                                                                                                                           | `http://proxy.example.com`                                                                |
| `webProxy.https`                                            | Web Proxy address for `HTTPS` traffic                                                                                                                                          | `https://proxy.example.com`                                                               |
| `webProxy.noProxy`                                          | Patterns for IP addresses or k8s services name or domain names that shouldn’t use the Web Proxy                                                                                | `localhost,127.0.0.1,docservice`                                                          |
| `privateCluster`                                            | Specify whether the k8s cluster is used in a private network without internet access                                                                                           | `false`                                                                                   |
| `upgrade.job.enabled`                                       | Enable the execution of job pre-upgrade before upgrading ONLYOFFICE Docs                                                                                                       | `true`                                                                                    |
| `upgrade.job.image.repository`                              | Job by upgrade image repository                                                                                                                                                | `onlyoffice/docs-utils`                                                                   |
| `upgrade.job.image.tag`                                     | Job by upgrade image tag                                                                                                                                                       | `7.3.0-1`                                                                                 |
| `upgrade.job.image.pullPolicy`                              | Job by upgrade image pull policy                                                                                                                                               | `IfNotPresent`                                                                            |
| `upgrade.job.resources.requests`                            | The requested resources for the job pre-upgrade container                                                                                                                      | `{}`                                                                                      |
| `upgrade.job.resources.limits`                              | The resources limits for the job pre-upgrade container                                                                                                                         | `{}`                                                                                      |
| `upgrade.existingConfigmap.tblRemove.name`                  | The name of the existing ConfigMap that contains the sql file for deleting tables from the database                                                                            | `remove-db-scripts`                                                                       |
| `upgrade.existingConfigmap.tblRemove.keyName`               | The name of the sql file containing instructions for deleting tables from the database. Must be the same as the `key` name in `upgrade.existingConfigmap.tblRemove.name`       | `removetbl.sql`                                                                           |
| `upgrade.existingConfigmap.tblCreate.name`                  | The name of the existing ConfigMap that contains the sql file for craeting tables from the database                                                                            | `init-db-scripts`                                                                         |
| `upgrade.existingConfigmap.tblCreate.keyName`               | The name of the sql file containing instructions for creating tables from the database. Must be the same as the `key` name in `upgrade.existingConfigmap.tblCreate.name`       | `createdb.sql`                                                                            |
| `upgrade.existingConfigmap.dsStop`                          | The name of the existing ConfigMap that contains the ONLYOFFICE Docs upgrade script. If set, the four previous parameters are ignored. Must contain a key `stop.sh`            | `""`                                                                                      |
| `rollback.job.enabled`                                      | Enable the execution of job pre-rollback before rolling back ONLYOFFICE Docs                                                                                                   | `true`                                                                                    |
| `rollback.job.image.repository`                             | Job by rollback image repository                                                                                                                                               | `onlyoffice/docs-utils`                                                                   |
| `rollback.job.image.tag`                                    | Job by rollback image tag                                                                                                                                                      | `7.3.0-1`                                                                                 |
| `rollback.job.image.pullPolicy`                             | Job by rollback image pull policy                                                                                                                                              | `IfNotPresent`                                                                            |
| `rollback.job.resources.requests`                           | The requested resources for the job rollback container                                                                                                                         | `{}`                                                                                      |
| `rollback.job.resources.limits`                             | The resources limits for the job rollback container                                                                                                                            | `{}`                                                                                      |
| `rollback.existingConfigmap.tblRemove.name`                 | The name of the existing ConfigMap that contains the sql file for deleting tables from the database                                                                            | `remove-db-scripts`                                                                       |
| `rollback.existingConfigmap.tblRemove.keyName`              | The name of the sql file containing instructions for deleting tables from the database. Must be the same as the `key` name in `rollback.existingConfigmap.tblRemove.name`      | `removetbl.sql`                                                                           |
| `rollback.existingConfigmap.tblCreate.name`                 | The name of the existing ConfigMap that contains the sql file for craeting tables from the database                                                                            | `init-db-scripts`                                                                         |
| `rollback.existingConfigmap.tblCreate.keyName`              | The name of the sql file containing instructions for creating tables from the database. Must be the same as the `key` name in `rollback.existingConfigmap.tblCreate.name`      | `createdb.sql`                                                                            |
| `rollback.existingConfigmap.dsStop`                         | The name of the existing ConfigMap that contains the ONLYOFFICE Docs rollback script. If set, the four previous parameters are ignored. Must contain a key `stop.sh`           | `""`                                                                                      |
| `delete.job.enabled`                                        | Enable the execution of job pre-delete before deleting ONLYOFFICE Docs                                                                                                         | `true`                                                                                    |
| `delete.job.image.repository`                               | Job by delete image repository                                                                                                                                                 | `onlyoffice/docs-utils`                                                                   |
| `delete.job.image.tag`                                      | Job by delete image tag                                                                                                                                                        | `7.3.0-1`                                                                                 |
| `delete.job.image.pullPolicy`                               | Job by delete image pull policy                                                                                                                                                | `IfNotPresent`                                                                            |
| `delete.job.resources.requests`                             | The requested resources for the job delete container                                                                                                                           | `{}`                                                                                      |
| `delete.job.resources.limits`                               | The resources limits for the job delete container                                                                                                                              | `{}`                                                                                      |
| `delete.existingConfigmap.tblRemove.name`                   | The name of the existing ConfigMap that contains the sql file for deleting tables from the database                                                                            | `remove-db-scripts`                                                                       |
| `delete.existingConfigmap.tblRemove.keyName`                | The name of the sql file containing instructions for deleting tables from the database. Must be the same as the `key` name in `delete.existingConfigmap.tblRemove.name`        | `removetbl.sql`                                                                           |
| `delete.existingConfigmap.dsStop`                           | The name of the existing ConfigMap that contains the ONLYOFFICE Docs delete script. If set, the two previous parameters are ignored. Must contain a key `stop.sh`              | `""`                                                                                      |
| `install.job.enabled`                                       | Enable the execution of job pre-install before installing ONLYOFFICE Docs                                                                                                      | `true`                                                                                    |
| `install.job.image.repository`                              | Job by pre-install ONLYOFFICE Docs image repository                                                                                                                            | `onlyoffice/docs-utils`                                                                   |
| `install.job.image.tag`                                     | Job by pre-install ONLYOFFICE Docs image tag                                                                                                                                   | `7.3.0-1`                                                                                 |
| `install.job.image.pullPolicy`                              | Job by pre-install ONLYOFFICE Docs image pull policy                                                                                                                           | `IfNotPresent`                                                                            |
| `install.job.resources.requests`                            | The requested resources for the job pre-install container                                                                                                                      | `{}`                                                                                      |
| `install.job.resources.limits`                              | The resources limits for the job pre-install container                                                                                                                         | `{}`                                                                                      |
| `install.existingConfigmap.tblCreate.name`                  | The name of the existing ConfigMap that contains the sql file for craeting tables from the database                                                                            | `init-db-scripts`                                                                         |
| `install.existingConfigmap.tblCreate.keyName`               | The name of the sql file containing instructions for creating tables from the database. Must be the same as the `key` name in `install.existingConfigmap.tblCreate.name`       | `createdb.sql`                                                                            |
| `install.existingConfigmap.initdb`                          | The name of the existing ConfigMap that contains the initdb script. If set, the two previous parameters are ignored. Must contain a key `initdb.sh`                            | `""`                                                                                      |

* *Note: The prefix `-de` is specified in the value of the image repository, which means solution type. Possible options:
  - Nothing is specified. For the open-source community version
  - `-de`. For commercial Developer Edition
  - `-ee`. For commercial Enterprise Edition

  If you use the community version, there may be problems with co-editing documents.

  The default value of this parameter refers to the ONLYOFFICE Document Server Developer Edition. To learn more about this edition and compare it with other editions, please see the comparison table on [this page](https://github.com/ONLYOFFICE/DocumentServer#onlyoffice-document-server-editions).

Specify each parameter using the --set key=value[,key=value] argument to helm install. For example,

```bash
$ helm install documentserver onlyoffice/docs --set ingress.enabled=true,ingress.ssl.enabled=true,ingress.host=example.com
```

This command gives expose documentServer via HTTPS.

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

### 5.3 Expose DocumentServer

#### 5.3.1 Expose DocumentServer via Service (HTTP Only)

*You should skip step[#5.3.1](#531-expose-documentserver-via-service-http-only) if you are going to expose DocumentServer via HTTPS*

This type of exposure has the least overheads of performance, it creates a loadbalancer to get access to DocumentServer.
Use this type of exposure if you use external TLS termination, and don't have another WEB application in the k8s cluster.

To expose DocumentServer via service, set the `service.type` parameter to LoadBalancer:

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


#### 5.3.2 Expose DocumentServer via Ingress

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

#### 5.3.2.2 Expose DocumentServer via HTTP

*You should skip step[5.3.2.2](#5322-expose-documentserver-via-http) if you are going to expose DocumentServer via HTTPS*

This type of exposure has more overheads of performance compared with exposure via service, it also creates a loadbalancer to get access to DocumentServer. 
Use this type if you use external TLS termination and when you have several WEB applications in the k8s cluster. You can use the one set of ingress instances and the one loadbalancer for those. It can optimize the entry point performance and reduce your cluster payments, cause providers can charge a fee for each loadbalancer.

To expose DocumentServer via ingress HTTP, set the `ingress.enabled` parameter to true:

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

#### 5.3.2.3 Expose DocumentServer via HTTPS

This type of exposure allows you to enable internal TLS termination for DocumentServer.

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

### 6. Scale DocumentServer (optional)

*This step is optional. You can skip step [6](#6-scale-documentserver-optional) entirely if you want to use default deployment settings.*

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

where `POD_COUNT` is а number of the `docservice` pods.

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
  
Running the helm upgrade command runs a hook that shuts down the documentserver and cleans up the database. This is needed when updating the version of documentserver. The default hook execution time is 300s.
The execution time can be changed using --timeout [time], for example

```bash
$ helm upgrade documentserver -f values.yaml onlyoffice/docs --timeout 15m
```

Note: When upgrading ONLYOFFICE Docs in a private k8s cluster behind a Web proxy or with no internet access, see the [notes](#10-run-jobs-in-a-private-k8s-cluster-optional) below.

If you want to update any parameter other than the version of the DocumentServer, then run the `helm upgrade` command without `hooks`, for example:

```bash
$ helm upgrade documentserver onlyoffice/docs --set jwt.enabled=false --no-hooks
```

To rollback updates, run the following command:

```bash
$ helm rollback documentserver
```

Note: When rolling back ONLYOFFICE Docs in a private k8s cluster behind a Web proxy or with no internet access, see the [notes](#10-run-jobs-in-a-private-k8s-cluster-optional) below.
  
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
$ kubectl delete secret license -n <NAMESPACE>
$ kubectl create secret generic license --from-file=path/to/license.lic -n <NAMESPACE>
```
 - Restart `docservice` and `converter` pods. For example, using the following command:
```bash
$ kubectl delete pod converter-*** docservice-*** -n <NAMESPACE>
```

### 10. Run Jobs in a private k8s cluster (optional)

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
If DocumentServer is already installed you need to run the `helm upgrade documentserver onlyoffice/docs --set grafana.enabled=true --set grafana.dashboard.enabled=true --no-hooks` command or `helm upgrade documentserver -f ./values.yaml onlyoffice/docs --no-hooks` if the parameters are specified in the [values.yaml](values.yaml) file.
As a result, ready-made dashboards in the `JSON` format will be downloaded from the Grafana [website](https://grafana.com/grafana/dashboards),
the necessary edits will be made to them and configmap will be created from them. A dashboard will also be added to visualize metrics coming from the DocumentServer (it is assumed that step [#6](#6-deploy-statsd-exporter) has already been completed).

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
  --set dashboardsConfigMaps[6].fileName=documentserver-statsd-exporter.json
```

After executing this command, the following dashboards will be imported into Grafana:

  - Node Exporter
  - Deployment Statefulset Daemonset
  - Redis Dashboard for Prometheus Redis Exporter
  - RabbitMQ-Overview
  - PostgreSQL Database
  - NGINX Ingress controller
  - DocumentServer

Note: You can see the description of the DocumentServer metrics that are visualized in Grafana [here](https://github.com/ONLYOFFICE/Kubernetes-Docs/wiki/Document-Server-Metrics).

See more details about installing Grafana via Helm [here](https://github.com/bitnami/charts/tree/master/bitnami/grafana).

### 2 Access to Grafana via Ingress

Note: It is assumed that step [#5.3.2.1](#5321-installing-the-kubernetes-nginx-ingress-controller) has already been completed.

If DocumentServer was installed with the parameter `grafana.ingress.enabled` (step [#5.2](#52-metrics-deployment-optional)) then access to Grafana will be at: `http://INGRESS-ADDRESS/grafana/`

If Ingres was installed using a secure connection (step [#5.3.2.3](#5323-expose-documentserver-via-https)), then access to Grafana will be at: `https://your-domain-name/grafana/`

### 3. View gathered metrics in Grafana

Go to the address `http(s)://your-domain-name/grafana/`

Login - admin

To get the password, run the following command:
```
$ kubectl get secret grafana-admin --namespace default -o jsonpath="{.data.GF_SECURITY_ADMIN_PASSWORD}" | base64 --decode
```

In the dashboard section, you will see the added dashboards that will display the metrics received from Prometheus.
