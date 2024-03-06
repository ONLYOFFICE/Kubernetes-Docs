# Change log

## 4.1.0

### New Features

* Added the ability set up annotations for all the deployed resources

### Changes

* Changes were made when connecting S3 bucket as a cache
* Changes in the image that is used in the `helm test` and edits in the executing script
* Released [v8.0.1](https://github.com/ONLYOFFICE/DocumentServer/blob/master/CHANGELOG.md#801) of ONLYOFFICE Docs

### Fixes

* Fixed a bug when adding multiline annotations to Ingress

## 4.0.0

### New Features

* Added the ability to connect to Redis Cluster 
* Added the ability to set up custom `podAntiAffinity`
* Added the ability to set up max size uploaded file
* Added the ability to map config file to Example

### Changes

* Updated the Security Context Constraints policy for OpenShift
* Released [v8.0.0](https://github.com/ONLYOFFICE/DocumentServer/blob/master/CHANGELOG.md#800) of ONLYOFFICE Docs

## 3.5.0

### New Features

* Added the ability to restrict access to the info page

## 3.4.1

### Changes

* Released [v7.5.1](https://github.com/ONLYOFFICE/DocumentServer/blob/master/CHANGELOG.md#751) of ONLYOFFICE Docs

## 3.4.0

### Changes

* Released [v7.5.0](https://github.com/ONLYOFFICE/DocumentServer/blob/master/CHANGELOG.md#750) of ONLYOFFICE Docs

## 3.3.0

### New Features

* Added the ability to connect to the ONLYOFFICE Docs via a virtual path
* Added the ability to connect to Redis Sentinel 

### Changes

* Released [v7.4.1](https://github.com/ONLYOFFICE/DocumentServer/blob/master/CHANGELOG.md#741) of ONLYOFFICE Docs

### Fixes

* Fixed Ingress Class definition

## 3.2.0

### New Features

* Added the ability to use private IP addresses to connect to ONLYOFFICE Docs

### Changes

* Released [v7.4.0](https://github.com/ONLYOFFICE/DocumentServer/blob/master/CHANGELOG.md#740) of ONLYOFFICE Docs

### Fixes

* Fixed ONLYOFFICE Docs crash in k8s cluster without ipv6
* Fixed an error with the Api Version when running Horizontal Pod Autoscaling in k8s cluster v1.26+

## 3.1.0

### New Features

* Added `helm test` for ONLYOFFICE Docs launch testing and connected dependencies availability testing
* Added `NOTES.txt`
* Added the ability set up `imagePullSecrets`

### Fixes

* Fixed variable handling for DocumentServer metrics

## 3.0.2

### Changes

* Released [v7.3.3](https://github.com/ONLYOFFICE/DocumentServer/blob/master/CHANGELOG.md#733) of ONLYOFFICE Docs

## 3.0.1

### Fixes

* Fixed a set of dashboards for Grafana

## 3.0.0

### New Features

* Added the ability set up session affinity for the "DocumentServer" Service
* Automated installation of ready-made Grafana dashboards

### Changes

* Released [v7.3.2](https://github.com/ONLYOFFICE/DocumentServer/blob/master/CHANGELOG.md#732) of ONLYOFFICE Docs
* Changed the Helm repository of the NFS Server Provisioner chart

### Fixes

* Fixed a bug with displaying solution type on the welcome page

## 2.2.0

### New Features

* Added the ability to disable the welcome page
* Added the ability set up custom Init Containers

### Changes

* Released [v7.2.2](https://github.com/ONLYOFFICE/DocumentServer/blob/master/CHANGELOG.md#722) of ONLYOFFICE Docs

## 2.1.0

### New Features

* Added additional parameters to connect to Redis
* Added the ability to specify an existing ServiceAccount or create a new one
* Added the ability set up custom `labels`, `nodeAffinity`, `podAffinity` and `namespace`

### Fixes

* Fixed service port in ONLYOFFICE Docs ingress

## 2.0.1

### New Features

* Added the ability to set up a list of IP addresses to access the Info page

### Changes

* Released [v7.2.1](https://github.com/ONLYOFFICE/DocumentServer/blob/master/CHANGELOG.md#721) of ONLYOFFICE Docs

## 2.0.0

### New Features

* Added the ability to use MySQL or MariaDB as a database server
* Added the ability set up `updateStrategy`
* Added the ability set up `containerPorts`

### Changes

* Released [v7.2.0](https://github.com/ONLYOFFICE/DocumentServer/blob/master/CHANGELOG.md#720) of ONLYOFFICE Docs
* Changed the syntax and algorithm for processing the following parameters: `Affinity`, `SecurityContext`, `Probes`, `Images`
* Changed the Redis version
* Changed the Welcome page

## 1.1.3

### Fixes

* Fixed the path to sql scripts

## 1.1.2

### Fixes

* Fixed running Jobs in an OpenShift cluster

## 1.1.1

### New Features

* Added the ability to disable the run of Jobs

### Fixes

* Fixed errors when connecting via the WOPI protocol
* Fixed the conversion error in Example

## 1.1.0

### New Features

* Added the ability to perform Jobs: `pre-upgrade`, `pre-rollback` and `pre-delete` in private k8s cluster
* Added `Job` `pre-install` (with support for execution in private cluster) to initialize the database before starting ONLYOFFICE Docs
* Added the ability to run ONLYOFFICE Docs in a private k8s cluster behind a Web Proxy

### Changes

* Changed the algorithm in the deletion script, which is executed in `Job` `pre-delete`
* Changed the image for the Jobs, which includes the utilities necessary for execution
* Changed the scripts executed by Jobs, taking into account the image change

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

