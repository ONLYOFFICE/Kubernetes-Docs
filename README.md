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

```bash
$ kubectl apply -f ./persistance/ds-files.yaml
```

Note: Default `nfs` Persistent Volume Claim is 8Gi. You can change it in `./persistance/ds-files.yaml` file in `spec.resources.requests.storage` section. It should be less than `PERSISTENT_SIZE` at least by about 5%. Recommended use 8Gi or more for persistent storage for every 100 active users of ONLYOFFICE DocumentServer.

Verify `ds-files` status

```bash
$ kubectl get persistance ds-files
```

Output

```
NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
ds-files   Bound    persistance-XXXXXXXX-XXXXXXXXX-XXXX-XXXXXXXXXXXX   8Gi        RWX            nfs            1m
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

To get postgresql and rabbitmq passwords, run the following commands:
```bash
$ kubectl get secret postgresql -o jsonpath="{.data.postgresql-password}" | base64 --decode
```
```bash
$ kubectl get secret rabbitmq -o jsonpath="{.data.rabbitmq-password}" | base64 --decode
```

Then, to install the RabbitMQ to your cluster, run the folowing command:
```bash
$ helm install documentserver ./kube-documentserver --set connections.dbPassword=`password` --set connections.amqpPassword=`password`
```

### 2. Custom database and/or AM (optional)

If your database and/or AM located outside of current kubernetes cluster or has custom connection, set it in `connections` parameters, for example:

```bash
$ helm install documentserver ./kube-documentserver --set connections.dbHost=examplehost --set connections.dbUser=exampleuser
```

The same goes for amqp parameters.

### 3. Example deployment (optional)

To deploy example set `example.install` parameter to true:

```bash
$ helm install documentserver ./kube-documentserver --set example.install=true
```

### 4. StatsD deployment (optional)
To deploy StatsD set `connections.metricsEnabled` to true:
```bash
$ helm install documentserver ./kube-documentserver --set connections.metricsEnables=true
```

### 5. Expose DocumentServer

#### 5.1 Expose DocumentServer via Service (HTTP Only)
*You should skip #5.1 step if you are going expose DocumentServer via HTTPS*

This type of exposure has the least overheads of performance, it creates a loadbalancer to get access to DocumentServer.
Use this type of exposure if you use external TLS termination, and don't have another WEB application in k8s cluster.

To expose DocumentServer via service set `service.type` parameter to LoadBalancer:

```bash
$ helm install documentserver ./kube-documentserver --set service.type=LoadBalancer

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

#### 5.2.2 Expose DocumentServer via HTTP

*You should skip #5.2.2 step if you are going expose DocumentServer via HTTPS*

This type of exposure has more overheads of performance compared with exposure via service, it also creates a loadbalancer to get access to DocumentServer. 
Use this type if you use external TLS termination and when you have several WEB applications in the k8s cluster. You can use the one set of ingress instances and the one loadbalancer for those. It can optimize entry point performance and reduce your cluster payments, cause providers can charge a fee for each loadbalancer.

To expose DocumentServer via ingress HTTP set `ingress.enabled` parameter to true:

```bash
$ helm install documentserver ./kube-documentserver --set ingress.enabled=true

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

To expose DocumentServer via ingress HTTPS set `ingress.enabled` parameter to true, `ingress.ssl.enabled` to true and change default  value for host:

```bash
$ helm install documentserver ./kube-documentserver --set ingress.enabled=true --set ingress.ssl.enabled=true --set ingress.ssl.host=example.com

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

After it ONLYOFFICE DocumentServer will be available at `https://your-domain-name/`.l

### 6. Available Configuration Parameters

| Parameter                         | Description                                      | Default                                     |
|-----------------------------------|--------------------------------------------------|---------------------------------------------|
| connections.dbHost                | IP address or the name of the database           | postgres                                    |
| connections.dbPort                | database server port number                      | 5432                                        |
| connections.dbUser                | database user                                    | postgres                                    |
| connections.dbPassword            | database password                                | postgres                                    |
| connections.redistServerHost      | IP address or the name of the redis host         | redis-master                                |
| connections.amqpHost              | IP address or the name of the message-broker     | rabbit-mq                                   |
| connections.amqpUser              | messabe-broker user                              | user                                        |
| connections.amqpPassword          | amqp password                                    | rabbitmq                                    |
| connections.amqpProto             | messabe-broker protocol                          | ampq                                        |
| persistance.storageClass          | storage class name                               | "nfs"                                       |
| persistance.size                  | storage volume size                              | 6Gi                                         |
| metrics.enabled                   | Statsd installation                              | false                                       |
| example.enabled                   | Choise of example installation                   | false                                       |
| example.name                      | Example name                                     | example                                     |
| example.containerImage            | example container image name                     | onlyoffice/4testing-ds-example:5.5.3        |
| docservice.replicas               | docservice replicas quantity                     | 2                                           |
| docservice.proxyContainerImage    | docservice proxy container image name            | onlyoffice/4testing-ds-proxy:5.5.3          |
| docservice.containerImage         | docservice container image name                  | onlyoffice/4testing-ds-docservice:5.5.3     |
| converter.replicas                | converter replicas quantity                      | 2                                           |
| converter.containerImage          | converter container image name                   | onlyoffice/4testing-ds-converter:5.5.3      |
| spellchecker.replicas             | spellchecker replicas quantity                   | 2                                           |
| spellchecker.containerImage       | spellchecker container image name                | onlyoffice/4testing-ds-spellchecker:5.5.3   |
| jwt.enabled                       | jwt enabling parameter                           | true                                        |
| jwt.secret                        | jwt secret                                       | MYSECRET                                    |
| service.type                      | documentserver service type                      | ClusterIP                                   |
| service.port                      | documentserver service port                      | 80                                          |
| ingress.enabled                   | installation of ingress service                  | false                                       |
| ingress.ssl.enabled               | installation ssl for ingress service             | false                                       |
| ingress.ssl.host                  | host for ingress ssl                             | example.com                                 |
| ingress.ssl.secret                | secret name for ssl                              | tls                                         |


