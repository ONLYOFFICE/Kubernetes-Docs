# Change log

## 1.0.1

### New Features

* Added the ability to specify an existing `Service` for "DocumentServer"

### Changes

* Release v7.1.1 of ONLYOFFICE Docs
* Added a variable to specify the port number of the `Redis` server in `ConfigMap` `documentserver`

### Fixes

* Fixed the name of the variable for specifying the host of the Redis server

## 1.0.0

### New Features

* Added the ability set up Horizontal Pod Autoscaling
* Added the ability set up `nodeSelector` and `tolerations`
* Added the ability set up annotations for ingress
* Added build of Helm Chart releases with their publication in the repository
* Added a description of the DocumentServer metrics that are visualized in Grafana

### Changes

* Release v7.1.0 of ONLYOFFICE Docs
* Changed the Helm Chart name from `documentserver` to `docs`
* Changed the Helm Chart versioning to the `SemVer` format
* Removed the instruction for updating the "DocumentServer" using a script

## 22.5.4

### New Features

* Added the ability to map a `ConfigMap` containing its own json file with interface themes
* Added the ability to specify different `JWT` parameters for inbox and outbox requests
* Added the ability to use `activemq` as an `AMQP` server
* Added the ability set up `annotations` for `Pods`
* Added the ability set up `annotations` for `Service`

## 22.4.15

### New Features

* Added the ability to specify the type and template of logging
* Added the ability to specify an existing `Secret` with `JWT` variables
* Added the ability to rollback `helm rollback` after updating "DocumentServer" via `helm upgrade`
* Added the ability to use existing `PVC` or `Secret` to store the license

### Changes

* Edits to the Helm Chart release deletion procedure
* Changed the Helm Chart versioning to the `CalVer` format

## 7.0.1

### New Features

* Added the ability to upgrade using `helm upgrade`
* Added the ability to map node-config files
* Added a `podAntiAffinity` policy for distributing `Pods` across the `Nodes` of the "k8s" cluster
* Added the ability to specify an existing `PVC` for "DocumentServer"
* Added the ability to specify existing `Secrets` containing passwords for `PostgreSQL` and `RabbitMQ`
* Added the ability to specify the DNS name when installing with Nginx Ingress Controller without certificates

### Changes

* Release v7.0.1 of ONLYOFFICE Docs
* Edited the instructions for installing metrics
* Improved the update and shutdown scripts
* Added the list of variables in `ConfigMap` `documentserver` and in `Secret` `jwt`

### Fixes

* Fixed the operation of `Example` when installing with Nginx Ingress Controller

## 7.0.0

### Changes

* Release v7.0.0 of ONLYOFFICE Docs

