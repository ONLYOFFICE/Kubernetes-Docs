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

  Persistent Storage Classes for different providers:
  - Digital Ocean: `do-block-storage`

- `PERSISTENT_SIZE` is the total size of all Persistent Storages for nfs Persistent Storage Class. You can express size as a plain integer one of these suffixes: `T`, `G`, `M`, `Ti`, `Gi`, `Mi`. For example: `200Gi`.

Create Persistent Volume Claim
```
$ kubectl apply -f ./pvc/ds-files.yaml
```
Note: Default `nfs` Persistent Volume Claim is 5Gi. You can change it in `./pvc/ds-files.yaml` file in `spec.resources.requests.storage` section. It should be less than `PERSISTENT_SIZE`.
### 2. Installing the Kubernetes Nginx Ingress Controller

To install the Nginx Ingress Controller to your cluster, run the following command:
```
$ helm install nginx-ingress stable/nginx-ingress --set controller.publishService.enabled=true
```

### 3. Deploy RabbitMQ
Deploy message broker pod:
```
$ kubectl apply -f ./pods/mb.yaml
```
Deploy `mb` service:
```
$ kubectl apply -f ./services/mb.yaml
```

### 4. Deploy Redis
Deploy lock storage pod:
```
$ kubectl apply -f ./pods/ls.yaml
```
Deploy `ls` service:
```
$ kubectl apply -f ./services/ls.yaml
```

### 5. Deploy PostgreSQL
Create secret `db` with database user name and password
```
$ kubectl create secret generic db \
  --from-literal=DB_USER=MYUSER \
  --from-literal=DB_PWD=MYUSERPWD
```
`MYUSER` and `MYPASSWORD` are database superuser name and password.

Note:
Special characters such as $, \, *, and ! will be interpreted by your shell and require escaping. In most shells, the easiest way to escape the password is to surround it with single quotes (')

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
If you have valid ONLYOFFICE DocumentServer license, create secret `license` from file.
```
$ kubectl create secret generic license \
  --from-file=./license.lic
```
Note: The source license file name should be 'license.lic' because this name would be used as a field in created secret.

Otherwise create empty secret `license` with follow command:
```
$ kubectl create secret generic license
```

### 2. Deploy ONLYOFFICE DocumentServer parameters
Deploy DocumentServer configmap:
```
$ kubectl apply -f ./configmaps/documentserver.yaml
```

Create `jwt` secret with JWT parameters
```
$ kubectl create secret generic jwt \
  --from-literal=JWT_ENABLED=true \
  --from-literal=JWT_SECRET=MYSECRET
```
`MYSECRET` is the secret key to validate the JSON Web Token in the request to the ONLYOFFICE Document Server.

### 3. Deploy DocumentServer

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


### 4. Deploy DocumentServer Example

This step is optional. You can skip #4 step at all if you don't wanna run DocumentServer Example

Deploy example configmap:
```
$ kubectl apply -f ./configmaps/example.yaml
```

Deploy example pod:
```
$ kubectl apply -f ./pods/example.yaml
```
Deploy example service:
```
$ kubectl apply -f ./services/example.yaml
```

### 5. Expose DocumentServer via HTTP

You should skip #5 step if you are going expose DocumentServer via HTTPS

Deploy documentserver ingress

```
$ kubectl apply -f ./ingresses/documentserver.yaml
```

Run next command to get `documentserver` ingress IP:
```
$ kubectl get ingress documentserver -o jsonpath="{.status.loadBalancer.ingress[*].ip}"
```

After it ONLYOFFICE DocumentServer will be available at `http://DOCUMENTSERVER-INGRESS-IP/`.

### 6. Expose DocumentServer via HTTPS

Create `tls` secret with ssl certificate inside.

Put ssl certificate and private key into `tls.crt` and `tls.key` file and than run:
```
$ kubectl create secret generic tls \
  --from-file=./tls.crt \
  --from-file=./tls.key
```

Open `./ingresses/documentserver-ssl.yaml` and type your domain name instead of `example.com`

Deploy documentserver ingress

```
$ kubectl apply -f ./ingresses/documentserver-ssl.yaml
```

Run next command to get `documentserver` ingress IP:
```
$ kubectl get ingress documentserver -o jsonpath="{.status.loadBalancer.ingress[*].ip}"
```

Associate `documentserver` ingress IP with your domain name through your DNS provider.

After it ONLYOFFICE DocumentServer will be available at `https://your-domain-name/`.