# ONLYOFFICE DocumentServer for Kubernetes

This repository contains a set of files to deploy ONLYOFFICE DocumentServer into Kubernetes cluster.

## Introduction

- You must have Openshift installed. Please, checkout [the reference](https://docs.openshift.com/container-platform/3.6/getting_started/install_openshift.html) to setup an Openshift.
- Or you should also have a local configured Minishift. See [this](https://docs.okd.io/3.11/minishift/getting-started/installing.html) guide how to install and configure Minishift.
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
$  oc create -f ./pvc/ds-files.yaml
```

Note: Default `nfs` Persistent Volume Claim is 8Gi. You can change it in `./pvc/ds-files.yaml` file in `spec.resources.requests.storage` section. It should be less than `PERSISTENT_SIZE` at least by about 5%. Recommended use 8Gi or more for persistent storage for every 100 active users of ONLYOFFICE DocumentServer.

Verify `ds-files` status

```bash
$ oc get pvc ds-files
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
$ oc create configmap init-db-scripts \
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

### 5. Deploy StatsD
*This step is optional. You can skip #6 step at all if you don't wanna run StatsD*

Deploy StatsD configmap:
```
$ oc create configmap --from-file=./configmaps/statsd.yaml
```
Deploy StatsD pod:
```
$ oc create -f ./pods/statsd.yaml
```
Deploy `statsd` service:
```
$ oc create -f ./services/statsd.yaml
```
Allow statsD metrics in ONLYOFFICE DocumentServer:

Put `data.METRICS_ENABLED` field in ./configmaps/documentserver.yaml file to `"true"` value

## Deploy ONLYOFFICE DocumentServer

### 1. Deploy ONLYOFFICE DocumentServer license

- If you have valid ONLYOFFICE DocumentServer license, create secret `license` from file.

    ```bash
    $ oc create -f ./license.lic
    ```

    Note: The source license file name should be 'license.lic' because this name would be used as a field in created secret.

- If you have no ONLYOFFICE DocumentServer license, create empty secret `license` with follow command:

    ```bash
    $ oc create secret generic license
    ```

### 2. Deploy ONLYOFFICE DocumentServer parameters

Deploy DocumentServer configmap:

```bash
$ oc create configmap documentserver --from-file=./configmaps/documentserver.yaml
```

Create `jwt` secret with JWT parameters

```bash
$ oc create secret generic jwt \
  --from-literal=JWT_ENABLED=true \
  --from-literal=JWT_SECRET=MYSECRET
```

`MYSECRET` is the secret key to validate the JSON Web Token in the request to the ONLYOFFICE Document Server.

### 3. Deploy DocumentServer

Deploy `spellchecker` deployment:

```bash
$ oc create -f ./deployments/spellchecker.yaml
```

Verify that the `spellchecker` deployment is running the desired number of pods with the following command.

```bash
$ oc get deployment spellchecker
```

Output

```
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
spellchecker   2/2     2            2           1m
```

Deploy spellchecker service:

```bash
$ oc create -f ./services/spellchecker.yaml
```

Deploy example service:

```bash
$ oc create -f ./services/example.yaml
```

Deploy docservice:

```bash
$ oc create -f ./services/docservice.yaml
```

Deploy `docservice` deployment:

```bash
$ oc create -f ./deployments/docservice.yaml
```

Verify that the `docservice` deployment is running the desired number of pods with the following command.

```bash
$ oc get deployment docservice
```

Output

```
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
docservice  2/2     2            2           1m
```

Deploy `converter` deployment:

```bash
$ oc create -f ./deployments/converter.yaml
```

Verify that the `converter` deployment is running the desired number of pods with the following command.

```bash
$ oc get deployment converter
```

Output

```
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
converter   2/2     2            2           1m
```

`docservice`, `converter` and `spellchecker` deployments consist of 2 pods each other by default.

To scale `docservice` deployment use follow command:

```bash
$ oc scale deployment docservice --replicas=POD_COUNT
```

where `POD_COUNT` is number of `docservice` pods

The same to scale `converter` and `spellchecker` deployment:

```bash
$ oc scale  deployment converter --replicas=POD_COUNT
```

```bash
$ oc scale deployment spellchecker --replicas=POD_COUNT
```

### 4. Deploy DocumentServer Example (optional)

*This step is optional. You can skip #4 step at all if you don't wanna run DocumentServer Example*

Deploy example configmap:

```bash
$ oc create configmap exapmle --from-file=./configmaps/example.yaml
```

Deploy example pod:

```bash
$ oc create -f ./pods/example.yaml
```

### 5. Expose DocumentServer

#### 5.1 Expose DocumentServer via Service (HTTP Only)
*You should skip #5.1 step if you are going expose DocumentServer via HTTPS*

This type of exposure has the least overheads of performance, it creates a loadbalancer to get access to DocumentServer.
Use this type of exposure if you use external TLS termination, and don't have another WEB application in k8s cluster.

Deploy `documentserver` service:

```bash
$ oc create -f ./services/documentserver-lb.yaml
```

Run next command to get `documentserver` service IP:

```bash
$ oc get service documentserver -o jsonpath="{.status.loadBalancer.ingress[*].ip}"
```

After it ONLYOFFICE DocumentServer will be available at `http://DOCUMENTSERVER-SERVICE-IP/`.

If service IP is empty try getting `documentserver` service hostname

```bash
$ oc get service documentserver -o jsonpath="{.status.loadBalancer.ingress[*].hostname}"
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
$ oc create -f ./services/documentserver.yaml
```

#### 5.2.2 Expose DocumentServer via HTTP

*You should skip #5.2.2 step if you are going expose DocumentServer via HTTPS*

This type of exposure has more overheads of performance compared with exposure via service, it also creates a loadbalancer to get access to DocumentServer. 
Use this type if you use external TLS termination and when you have several WEB applications in the k8s cluster. You can use the one set of ingress instances and the one loadbalancer for those. It can optimize entry point performance and reduce your cluster payments, cause providers can charge a fee for each loadbalancer.

Deploy documentserver ingress

```bash
$ oc create -f ./ingresses/documentserver.yaml
```

Run next command to get `documentserver` ingress IP:

```bash
$ oc get ingress documentserver -o jsonpath="{.status.loadBalancer.ingress[*].ip}"
```

After it ONLYOFFICE DocumentServer will be available at `http://DOCUMENTSERVER-INGRESS-IP/`.

If ingress IP is empty try getting `documentserver` ingress hostname

```bash
$ oc get ingress documentserver -o jsonpath="{.status.loadBalancer.ingress[*].hostname}"
```

In this case ONLYOFFICE DocumentServer will be available at `http://DOCUMENTSERVER-INGRESS-HOSTNAME/`.

#### 5.2.3 Expose DocumentServer via HTTPS

This type of exposure to enable internal TLS termination for DocumentServer.

Create `tls` secret with ssl certificate inside.

Put ssl certificate and private key into `tls.crt` and `tls.key` file and than run:

```bash
$ oc create secret generic tls \
  --from-file=./tls.crt \
  --from-file=./tls.key
```

Open `./ingresses/documentserver-ssl.yaml` and type your domain name instead of `example.com`

Deploy documentserver ingress

```bash
$ oc create -f ./ingresses/documentserver-ssl.yaml
```

Run next command to get `documentserver` ingress IP:

```bash
$ oc get ingress documentserver -o jsonpath="{.status.loadBalancer.ingress[*].ip}"
```

If ingress IP is empty try getting `documentserver` ingress hostname

```bash
$ oc get ingress documentserver -o jsonpath="{.status.loadBalancer.ingress[*].hostname}"
```

Associate `documentserver` ingress IP or hostname with your domain name through your DNS provider.

After it ONLYOFFICE DocumentServer will be available at `https://your-domain-name/`.

### 6. Update ONLYOFFICE DocumentServer
#### 6.1 Preparing for update

The next script creates a job, which shuts down the service, clears the cache files and clears tables in database.
Download ONLYOFFICE DocumentServer database script for database cleaning:

```bash
$ wget https://raw.githubusercontent.com/ONLYOFFICE/server/master/schema/postgresql/removetbl.sql
```

Create a config map from it:

```bash
$ oc create configmap remove-db-scripts --from-file=./removetbl.sql
```

Run the job:

```bash
$ oc create -f ./jobs/prepare4update.yaml
```

After successful run job automaticly terminates its pod, but you have to clean the job itself manually:

```bash
$ oc delete job prepare4update
```
#### 6.2 Update DocumentServer images

Update deployment images:
```
$ oc set image deployment/spellchecker \
  spellchecker=onlyoffice/4testing-ds-spellchecker:DOCUMENTSERVER_VERSION

$ oc set image deployment/converter \
  converter=onlyoffice/4testing-ds-converter:DOCUMENTSERVER_VERSION

$ oc set image deployment/docservice \
  docservice=onlyoffice/4testing-ds-docservice:DOCUMENTSERVER_VERSION \
  proxy=onlyoffice/4testing-ds-proxy:DOCUMENTSERVER_VERSION
```
`DOCUMENTSERVER_VERSION` is the new version of docker images for ONLYOFFICE DocumentServer.
