# ONLYOFFICE DocumentServer for Kubernetes

This repository contains a set of files to deploy ONLYOFFICE DocumentServer into Kubernetes cluster.

## Introduction

- You must have Kubernetes installed. Please, checkout [the reference](https://kubernetes.io/docs/setup/) to setup a Kubernetes.
- You should also have a local configured copy of `kubectl`. See [this](https://kubernetes.io/docs/tasks/tools/install-kubectl/) guide how to install and configure `kubectl`.
- You should install Helm v3, please follow the instruction [here](https://helm.sh/docs/intro/install/) to install it.

## Deploy prerequisites

### 1. Install Persistent Storage

Install NFS Server Provisioner

```bash
$ helm install nfs-server stable/nfs-server-provisioner \
  --set persistence.enabled=true \
  --set persistence.storageClass=PERSISTENT_STORAGE_CLASS \
  --set persistence.size=PERSISTENT_SIZE
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

```bash
$ kubectl apply -f ./pvc/ds-files.yaml
```

Note: Default `nfs` Persistent Volume Claim is 8Gi. You can change it in `./pvc/ds-files.yaml` file in `spec.resources.requests.storage` section. It should be less than `PERSISTENT_SIZE` at least by about 5%. Recommended use 8Gi or more for persistent storage for every 100 active users of ONLYOFFICE DocumentServer.

Verify `ds-files` status

```bash
$ kubectl get pvc ds-files
```

Output

```
NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
ds-files   Bound    pvc-XXXXXXXX-XXXXXXXXX-XXXX-XXXXXXXXXXXX   8Gi        RWX            nfs            1m
```

### 2. Deploy RabbitMQ

To install the RabbitMQ to your cluster, run the following command:

```bash
$ helm install rabbitmq stable/rabbitmq
```
See more detail about install RabbitMQ via Helm [here](https://github.com/helm/charts/tree/master/stable/rabbitmq#rabbitmq).

### 3. Deploy Redis

To install the Redis to your cluster, run the following command:

```bash
$ helm install redis stable/redis \
  --set cluster.enabled=false \
  --set usePassword=false
```

See more detail about install Redis via Helm [here](https://github.com/helm/charts/tree/master/stable/redis#redis).

### 4. Deploy PostgreSQL

Download ONLYOFFICE DocumentServer database scheme:

```bash
wget https://raw.githubusercontent.com/ONLYOFFICE/server/master/schema/postgresql/createdb.sql
```

Create a config map from it:

```bash
$ kubectl create configmap init-db-scripts \
  --from-file=./createdb.sql
```

To install the PostgreSQL to your cluster, run the following command:

```
$ helm install postgresql stable/postgresql \
  --set initdbScriptsConfigMap=init-db-scripts \
  --set postgresqlDatabase=postgres \
  --set persistence.size=PERSISTENT_SIZE
```

Here `PERSISTENT_SIZE` is a size for PostgreSQL persistent volume. For example: `8Gi`.

Recommended use at least 2Gi of persistent storage for every 100 active users of ONLYOFFICE DocumentServer.

See more detail about install PostgreSQL via Helm [here](https://github.com/helm/charts/tree/master/stable/postgresql#postgresql).


## Deploy ONLYOFFICE DocumentServer

### 1. Deploy DocumentServer

To install the RabbitMQ to your cluster, run the following command:

```bash
$ helm install documentserver ./kube-documentserver
```

### 2. Example deployment (optional)

To deploy example set `example.install` parameter to true:

```bash
$ helm install documentserver ./kube-documentserver --set example.install=true
```

### 3. StatsD deployment (optional)
To deploy StatsD set `connections.metricsEnabled` to true:
```bash
$ helm install documentserver ./kube-documentserver --set connections.metricsEnables=true
```


### 4. Available Configuration Parameters
**connections** section with parameters that configure connections to DB,ampq, etc.
- **dbHost** : The database name. Supported values are `postgres`, `mariadb` or `mysql`. Defaults to `postgres`.
- **dbUser** : The database user. Defaults to 'postgres'.
- **dbPort** : database port. Defaults to '5432'.
- **redistServerHost** : 
- **ampqHost** : message-broker type. Rabbitmq and activemq are supported. Defaults to 'rabbitmq'.
- **ampqUser** : messabe-broker user. Defaults to 'user'.
- **ampqProto** : messabe-broker protocol. defaults to 'ampq'.
- **metricsEnabled** : 
- **metricsHost** :
- **spellcheckerHostPort** :
- **exampleHostPort** : example:8080

**pvc** : section with parameters that configure persistent volume claims
- **name** : name of the claim. Defaults to `ds-files`.
- **storegaClassName** : Defaults to `"nfs"`.
- **storage** : Defaults to `6Gi`.
- **mountPath** : 

**example** : section with example parameters
- **install** : Specifies the installation of example. Defaults to `false`.
- **name** : The name of the example service.
- **containerName** : The container name of example service. Defaults to `example`.
- **containerImage** : 
- **containerPort** : 
- **environmentSecretReference** :
- **environmentConfigMapReference** :
- **DSURL** :

**docservice**: 
- **name** : 
- **app** :
- **replicas** :
- **configMap** :
- **proxyContainerImage** :
- **proxyContainerPort** :
- **docserviceContainerImage** :
- **docserviceContainerPort** :

**converter** :
- **name** :
- **app** :
- **replicas** : 
- **converterContainerImage** :

**spellchecker** :
- **name** :
- **app** :
- **replicas** :
- **spellcheckerContainerImage** :
- **spellcheckerContainerPort** :

**secrets** :
- **jwt** :
- **name** : 
- **type** :
- **immutable** :
- **jwtEnabled** :
- **jwtSecret** :

### 5. Expose DocumentServer

#### 5.1 Expose DocumentServer via Service (HTTP Only)
*You should skip #5.1 step if you are going expose DocumentServer via HTTPS*

This type of exposure has the least overheads of performance, it creates a loadbalancer to get access to DocumentServer.
Use this type of exposure if you use external TLS termination, and don't have another WEB application in k8s cluster.

Deploy `documentserver` service:

```bash
$ kubectl apply -f ./services/documentserver-lb.yaml
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


#### 5.2 Expose DocumentServer via Ingress

#### 5.2.1 Installing the Kubernetes Nginx Ingress Controller

To install the Nginx Ingress Controller to your cluster, run the following command:

```bash
$ helm install nginx-ingress stable/nginx-ingress --set controller.publishService.enabled=true,controller.replicaCount=2
```

See more detail about install Nginx Ingress via Helm [here](https://github.com/helm/charts/tree/master/stable/nginx-ingress#nginx-ingress).

Deploy `documentserver` service:

```bash
$ kubectl apply -f ./services/documentserver.yaml
```

#### 5.2.2 Expose DocumentServer via HTTP

*You should skip #5.2.2 step if you are going expose DocumentServer via HTTPS*

This type of exposure has more overheads of performance compared with exposure via service, it also creates a loadbalancer to get access to DocumentServer. 
Use this type if you use external TLS termination and when you have several WEB applications in the k8s cluster. You can use the one set of ingress instances and the one loadbalancer for those. It can optimize entry point performance and reduce your cluster payments, cause providers can charge a fee for each loadbalancer.

Deploy documentserver ingress

```bash
$ kubectl apply -f ./ingresses/documentserver.yaml
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

#### 5.2.3 Expose DocumentServer via HTTPS

This type of exposure to enable internal TLS termination for DocumentServer.

Create `tls` secret with ssl certificate inside.

Put ssl certificate and private key into `tls.crt` and `tls.key` file and than run:

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
