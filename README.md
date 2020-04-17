# ONLYOFFICE DocumentServer for Kubernetus

This repository contains a set of files to deploy ONLYOFFICE DocumentServer into Kubernetus cluster.

## Introduction

- You must have Kubernetes installed. Please, checkout [the reference](https://kubernetes.io/docs/setup/) to setup a Kubernetus.
- You should also have a local configured copy of `kubectl`. See [this](https://kubernetes.io/docs/tasks/tools/install-kubectl/) guide how to install and configure `kubectl`.
- You should install Helm v3, please follow the instruction [here](https://helm.sh/docs/intro/install/) to install it.

## Deploy prerequisites

### 1. Install Persistent Storage

Install `nfs` Persistent Storage Class
```
$ helm install nfs-server stable/nfs-server-provisioner \
  --set persistence.enabled=true,persistence.storageClass=PERSISTENT_STORAGE_CLASS,persistence.size=PERSISTENT_SIZE
```
- `PERSISTENT_STORAGE_CLASS` is Persistent Storage Class available in your Kubernetus cluster
- `PERSISTENT_SIZE` is the total size of all Persistent Storages for nfs Persistent Storage Class. You can express size as a plain integer one of these suffixes: `T`, `G`, `M`, `Ti`, `Gi`, `Mi`. For example: `200Gi`.

Persistent Storage Classes for different providers:
- Digital Ocean: `do-block-storage`
 
Create Persistent Volume Claim
```
$ kubectl apply -f ./pvc/ds-files.yaml
```
Note: Default `nfs` Persistent Volume Claim is 5Gi. You can change it in `./pvc/ds-files.yaml` file in `spec.resources.requests.storage` section. It should be less than `PERSISTENT_SIZE`.

### 2. Deploy RabbitMQ
Deploy message broker pod:
```
$ kubectl apply -f ./pods/mb.yaml
```
Deploy `mb` service:
```
$ kubectl apply -f ./services/mb.yaml
```

### 3. Deploy Redis
Deploy lock storage pod:
```
$ kubectl apply -f ./pods/ls.yaml
```
Deploy `ls` service:
```
$ kubectl apply -f ./services/ls.yaml
```

### 4. Deploy PostgreSQL
Deploy data base pod:
```
$ kubectl apply -f ./pods/db.yaml
```
Deploy `db` service:
```
$ kubectl apply -f ./services/db.yaml
```

## Deploy ONLYOFFICE DocumentServer

### 1. Deploy ONLYOFFICE DocumentServer license
If you have valid ONLYOFFICE DocumentServer license, put it to `data.license.lic` field in `./configmaps/license.yaml` file. Otherwise keep this that unchanged.
Deploy the license configmap:
```
$ kubectl apply -f ./configmaps/license.yaml
```

### 2. Deploy DocumentServer
Deploy DocumentServer configmap:
```
$ kubectl apply -f ./configmaps/documentserver.yaml
```

Deploy docservice deployment:
```
$ kubectl apply -f ./deployments/docservice.yaml
```

Deploy converter deployment:
```
$ kubectl apply -f ./deployments/converter.yaml
```

`docservice` and `converter` deployments consist of 2 pods each other by default.

To scale `docservice` deployment use follow command:
```
$ kubectl scale -n default deployment docservice --replicas=POD_COUNT
```
where `POD_COUNT` is number of `docservice` pods

The same to scale `converter` deployment:
```
$ kubectl scale -n default deployment converter --replicas=POD_COUNT
```

Deploy documentserver service:
```
$ kubectl apply -f ./services/documentserver.yaml
```
Run next command to get `documentserver` service IP:
```
$ get svc documentserver -o jsonpath="{.status.loadBalancer.ingress[*].ip}"
```

After it ONLYOFFICE DocumentServer will be available at `http://DOCUMENTSERVER-SERVICE-IP/`

## Deploy ONLYOFFICE DocumentServer Example

Put ONLYOFFICE DocumentServer URL to `data.DS_URL` field in `./configmaps/example.yaml` file.
You can use DocumentServer IP or domain name associated with this IP you got in the previous step in DocumentServer the URL.

Deploy example configmap:
```
$ kubectl apply -f ./configmaps/documentserver.yaml
```

Deploy example pod:
```
$ kubectl apply -f ./pods/example.yaml
```
Deploy example service:
```
$ kubectl apply -f ./services/example.yaml
```
Run next command to get `example` service IP:
```
$ get svc example -o jsonpath="{.status.loadBalancer.ingress[*].ip}"
```

After it ONLYOFFICE DocumentServer Example will be available at `http://EXAMPLE-SERVICE-IP/` in web browser.