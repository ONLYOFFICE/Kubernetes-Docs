# ONLYOFFICE Docs for Kubernetes

This repository contains a set of files to deploy ONLYOFFICE Docs into a Kubernetes cluster.

## Introduction

- You must have Kubernetes installed. Please, checkout [the reference](https://kubernetes.io/docs/setup/) to set up Kubernetes.
- You should also have a local configured copy of `kubectl`. See [this](https://kubernetes.io/docs/tasks/tools/install-kubectl/) guide how to install and configure `kubectl`.
- You should install Helm v3. Please follow the instruction [here](https://helm.sh/docs/intro/install/) to install it.
- If you're using Openshift instead of Kubernetes, use [these](openshift/README.md) instructions to deploy ONLYOFFICE Docs.

## Deploy prerequisites

### 1. Install Persistent Storage

Install NFS Server Provisioner

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

### 2. Deploy RabbitMQ

To install RabbitMQ to your cluster, run the following command:

```bash
$ helm install rabbitmq stable/rabbitmq
```
See more details about installing RabbitMQ via Helm [here](https://github.com/helm/charts/tree/master/stable/rabbitmq#rabbitmq).

### 3. Deploy Redis

To install Redis to your cluster, run the following command:

```bash
$ helm install redis stable/redis \
  --set cluster.enabled=false \
  --set usePassword=false
```

See more details about installing Redis via Helm [here](https://github.com/helm/charts/tree/master/stable/redis#redis).

### 4. Deploy PostgreSQL

Download the ONLYOFFICE Docs database scheme:

```bash
wget https://raw.githubusercontent.com/ONLYOFFICE/server/master/schema/postgresql/createdb.sql
```

Create a config map from it:

```bash
$ kubectl create configmap init-db-scripts \
  --from-file=./createdb.sql
```

To install PostgreSQL to your cluster, run the following command:

```
$ helm install postgresql stable/postgresql \
  --set initdbScriptsConfigMap=init-db-scripts \
  --set postgresqlDatabase=postgres \
  --set persistence.size=PERSISTENT_SIZE
```

Here `PERSISTENT_SIZE` is a size for the PostgreSQL persistent volume. For example: `8Gi`.

It's recommended to use at least 2Gi of persistent storage for every 100 active users of ONLYOFFICE Docs.

See more details about installing PostgreSQL via Helm [here](https://github.com/helm/charts/tree/master/stable/postgresql#postgresql).

### 5. Deploy StatsD
*This step is optional. You can skip step  #5 at all if you don't want to run StatsD*

Deploy the StatsD configmap:
```
$ kubectl apply -f ./configmaps/statsd.yaml
```
Deploy the StatsD pod:
```
$ kubectl apply -f ./pods/statsd.yaml
```
Deploy the `statsd` service:
```
$ kubectl apply -f ./services/statsd.yaml
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

*This step is optional. You can skip step  #4 at all if you don't want to run the DocumentServer Example*

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
*You should skip step  #5.1 if you are going to expose DocumentServer via HTTPS*

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
kubectl get service documentserver -o jsonpath="{.status.loadBalancer.ingress[*].hostname}"
```

In this case, ONLYOFFICE Docs will be available at `http://DOCUMENTSERVER-SERVICE-HOSTNAME/`.


#### 5.2 Expose DocumentServer via Ingress

#### 5.2.1 Installing the Kubernetes Nginx Ingress Controller

To install the Nginx Ingress Controller to your cluster, run the following command:

```bash
$ helm install nginx-ingress stable/nginx-ingress --set controller.publishService.enabled=true,controller.replicaCount=2
```

See more details about installing Nginx Ingress via Helm [here](https://github.com/helm/charts/tree/master/stable/nginx-ingress#nginx-ingress).

Deploy the `documentserver` service:

```bash
$ kubectl apply -f ./services/documentserver.yaml
```

#### 5.2.2 Expose DocumentServer via HTTP

*You should skip step #5.2.2 if you are going to expose DocumentServer via HTTPS*

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
kubectl get ingress documentserver -o jsonpath="{.status.loadBalancer.ingress[*].hostname}"
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
kubectl get ingress documentserver -o jsonpath="{.status.loadBalancer.ingress[*].hostname}"
```

Associate the `documentserver` ingress IP or hostname with your domain name through your DNS provider.

After that, ONLYOFFICE Docs will be available at `https://your-domain-name/`.

### 6. Update ONLYOFFICE Docs
#### 6.1 Preparing for update

The next script creates a job, which shuts down the service, clears the cache files and clears tables in the database.
Download the ONLYOFFICE Docs database script for database cleaning:

```bash
$ wget https://raw.githubusercontent.com/ONLYOFFICE/server/master/schema/postgresql/removetbl.sql
```

Create a config map from it:

```bash
$ kubectl create configmap remove-db-scripts --from-file=./removetbl.sql
```

Run the job:

```bash
$ kubectl apply -f ./jobs/prepare4update.yaml
```

After successful run, the job automaticly terminates its pod, but you have to clean the job itself manually:

```bash
$ kubectl delete job prepare4update
```
#### 6.2 Update the DocumentServer images

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
