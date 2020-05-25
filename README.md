# ONLYOFFICE DocumentServer for Kubernetus

This repository contains a set of files to deploy ONLYOFFICE DocumentServer into Kubernetus cluster.

## Introduction

- You must have Kubernetes installed. Please, checkout [the reference](https://kubernetes.io/docs/setup/) to setup a Kubernetus.
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

- `PERSISTENT_STORAGE_CLASS` is Persistent Storage Class available in your Kubernetus cluster

  Persistent Storage Classes for different providers:
  - Amazon EKS: `gp2`
  - Digital Ocean: `do-block-storage`
  - IBM Cloud: Default `ibmc-file-bronze`. [More storage classes](https://cloud.ibm.com/docs/containers?topic=containers-file_storage)
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

### 2. Installing the Kubernetes Nginx Ingress Controller

To install the Nginx Ingress Controller to your cluster, run the following command:

```bash
$ helm install nginx-ingress stable/nginx-ingress --set controller.publishService.enabled=true,controller.replicaCount=2
```

See more detail about install Nginx Ingress via Helm [here](https://github.com/helm/charts/tree/master/stable/nginx-ingress#nginx-ingress).

### 3. Deploy RabbitMQ

To install the RabbitMQ to your cluster, run the following command:

```bash
$ helm install rabbitmq stable/rabbitmq
```
See more detail about install RabbitMQ via Helm [here](https://github.com/helm/charts/tree/master/stable/rabbitmq#rabbitmq).

### 4. Deploy Redis

To install the Redis to your cluster, run the following command:

```bash
$ helm install redis stable/redis \
  --set cluster.enabled=false \
  --set usePassword=false
```

See more detail about install Redis via Helm [here](https://github.com/helm/charts/tree/master/stable/redis#redis).

### 5. Deploy PostgreSQL

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

### 6. Deploy StatsD
*This step is optional. You can skip #6 step at all if you don't wanna run StatsD*

Deploy StatsD configmap:
```
$ kubectl apply -f ./configmaps/statsd.yaml
```
Deploy StatsD pod:
```
$ kubectl apply -f ./pods/statsd.yaml
```
Deploy `statsd` service:
```
$ kubectl apply -f ./services/statsd.yaml
```
Allow statsD metrics in ONLYOFFICE DocumentServer:

Put `data.METRICS_ENABLED` field in ./configmaps/documentserver.yaml file to `"true"` value

## Deploy ONLYOFFICE DocumentServer

### 1. Deploy ONLYOFFICE DocumentServer license

- If you have valid ONLYOFFICE DocumentServer license, create secret `license` from file.

    ```bash
    $ kubectl create secret generic license \
      --from-file=./license.lic
    ```

    Note: The source license file name should be 'license.lic' because this name would be used as a field in created secret.

- If you have no ONLYOFFICE DocumentServer license, create empty secret `license` with follow command:

    ```bash
    $ kubectl create secret generic license
    ```

### 2. Deploy ONLYOFFICE DocumentServer parameters

Deploy DocumentServer configmap:

```bash
$ kubectl apply -f ./configmaps/documentserver.yaml
```

Create `jwt` secret with JWT parameters

```bash
$ kubectl create secret generic jwt \
  --from-literal=JWT_ENABLED=true \
  --from-literal=JWT_SECRET=MYSECRET
```

`MYSECRET` is the secret key to validate the JSON Web Token in the request to the ONLYOFFICE Document Server.

### 3. Deploy DocumentServer

Deploy `docservice` deployment:

```bash
$ kubectl apply -f ./deployments/docservice.yaml
```

Verify that the `docservice` deployment is running the desired number of pods with the following command.

```bash
$ kubectl get deployment docservice
```

Output

```
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
docservice  2/2     2            2           1m
```

Deploy `converter` deployment:

```bash
$ kubectl apply -f ./deployments/converter.yaml
```

Verify that the `converter` deployment is running the desired number of pods with the following command.

```bash
$ kubectl get deployment converter
```

Output

```
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
converter   2/2     2            2           1m
```

`docservice` and `converter` deployments consist of 2 pods each other by default.

To scale `docservice` deployment use follow command:

```bash
$ kubectl scale -n default deployment docservice --replicas=POD_COUNT
```

where `POD_COUNT` is number of `docservice` pods

The same to scale `converter` deployment:

```bash
$ kubectl scale -n default deployment converter --replicas=POD_COUNT
```

Deploy documentserver service:

```bash
$ kubectl apply -f ./services/documentserver.yaml
```

### 4. Deploy DocumentServer Example (optional)

*This step is optional. You can skip #4 step at all if you don't wanna run DocumentServer Example*

Deploy example configmap:

```bash
$ kubectl apply -f ./configmaps/example.yaml
```

Deploy example pod:

```bash
$ kubectl apply -f ./pods/example.yaml
```

Deploy example service:

```bash
$ kubectl apply -f ./services/example.yaml
```

### 5. Expose DocumentServer

#### 5.1 Expose DocumentServer via HTTP

*You should skip #5.1 step if you are going expose DocumentServer via HTTPS*

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

#### 5.1 Expose DocumentServer via HTTPS

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
