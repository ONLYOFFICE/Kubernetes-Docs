# Deploying Dependencies

The configurations below correspond to load testing with 5000 connections. Change the number/resources of the worker nodes and the parameter values if necessary.

It is assumed that all dependencies will be deployed in a clustered HA mode and that 3 worker nodes with 4 CPU and 8 GiB RAM each will be allocated for them, with the taint `For=dep:NoSchedule` and the label `For=dep` added. If you change these, update the corresponding fields in the manifests below.

## Deploy PostgreSQL Database

[CloudNativePG](https://cloudnative-pg.io/docs/devel/)

Install the CloudNativePG Operator:

```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update

helm install cnpg --version 0.29.0 \
  --namespace cnpg-system \
  --create-namespace \
  cnpg/cloudnative-pg
```

For more details, see [here](https://github.com/cloudnative-pg/charts/tree/main/charts/cloudnative-pg).

Create a `postgresql.yaml` manifest with the following content:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres
spec:
  instances: 3
  storage:
    size: 100Gi
    storageClass: PERSISTENT_STORAGE_CLASS
  bootstrap:
    initdb:
      database: onlyoffice
      owner: onlyoffice
  enableSuperuserAccess: false
  postgresql:
    parameters:
      max_connections: "400"
      shared_buffers: "2GB"
      work_mem: "4MB"
      maintenance_work_mem: "512MB"
      wal_buffers: "128MB"
      max_wal_size: "8GB"
      min_wal_size: "2GB"
      checkpoint_completion_target: "0.9"
      random_page_cost: "1.1"
      effective_cache_size: "6GB"
      effective_io_concurrency: "200"
  resources:
    requests:
      cpu: 500m
      memory: 2Gi
    limits:
      cpu: 4000m
      memory: 6Gi
  affinity:
    nodeSelector:
      For: dep
    tolerations:
      - key: For
        operator: Equal
        value: dep
        effect: NoSchedule
    enablePodAntiAffinity: true
    topologyKey: kubernetes.io/hostname
    podAntiAffinityType: preferred  

---
apiVersion: postgresql.cnpg.io/v1
kind: Pooler
metadata:
  name: postgres-pooler-rw
spec:
  cluster:
    name: postgres
  instances: 2
  type: rw
  pgbouncer:
    poolMode: transaction
    parameters:
      max_client_conn: "2000"
      default_pool_size: "50"
      min_pool_size: "10"
      reserve_pool_size: "20"
      reserve_pool_timeout: "3"
      max_db_connections: "100"
      server_idle_timeout: "600"
      server_lifetime: "3600"
      query_wait_timeout: "60"
      client_login_timeout: "30"
      server_check_delay: "30"
      server_check_query: "SELECT 1"
      ignore_startup_parameters: "extra_float_digits,search_path"
  template:
    spec:
      nodeSelector:
        For: dep
      tolerations:
        - key: For
          operator: Equal
          value: dep
          effect: NoSchedule
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    cnpg.io/poolerName: postgres-pooler-rw
                topologyKey: kubernetes.io/hostname
      containers:
        - name: pgbouncer
          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"
            limits:
              cpu: "4000m"
              memory: "4Gi"
```

> **Note:**\
> It is recommended to use at least 2Gi of persistent storage for every 100 active users of ONLYOFFICE Docs.

> **Note:**\
> The metrics exporter is enabled by default. Each PostgreSQL instance exposes
> Prometheus metrics on port `9187` (`/metrics`).
> The exporter is built into the instance manager and cannot be fully disabled;
> you can only drop the default query set by setting `spec.monitoring.disableDefaultQueries: true` in the `Cluster` manifest.

Apply the created manifest:

```bash
kubectl apply -f postgresql.yaml
```

This creates one master and two replicas. Two PgBouncer replicas will also be created.

> **Note:**\
> If you set `spec.instances: 1` in `kind: Cluster`, only the master will be created.

To install Docs, specify the corresponding parameters:

```yaml
connections:
  dbType: postgres
  dbHost: postgres-pooler-rw
  dbUser: onlyoffice
  dbPort: "5432"
  dbName: onlyoffice
  dbExistingSecret: postgres-app
  dbSecretKeyName: password
```

## Deploy RabbitMQ

[RabbitMQ Cluster Operator](https://www.rabbitmq.com/kubernetes/operator/operator-overview)

> **Note:**\
> Cluster Operator 2.20+ requires cert-manager to be installed. If cert-manager is not present in the cluster and installing it is undesirable, use Cluster Operator ≤ 2.19.

Install [cert-manager](https://cert-manager.io/docs/usage/gateway/). You can follow [this step](../README.md#5334-expose-onlyoffice-docs-via-https-using-the-lets-encrypt-certificate) of the instructions.

Install the RabbitMQ Cluster Operator:

```bash
kubectl apply -f https://github.com/rabbitmq/cluster-operator/releases/download/v2.22.3/cluster-operator.yml
```

For more details, see [here](https://github.com/rabbitmq/cluster-operator).

Create a `rabbitmq.yaml` manifest with the following content:

```yaml
apiVersion: rabbitmq.com/v1beta1
kind: RabbitmqCluster
metadata:
  name: rabbitmq
spec:
  replicas: 3
  persistence:
    storageClassName: PERSISTENT_STORAGE_CLASS
    storage: 10Gi
  rabbitmq:
    additionalConfig: |
      default_user = onlyoffice
      cluster_partition_handling = autoheal
      queue_leader_locator = balanced
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 4000m
      memory: 4Gi
  tolerations:
    - key: "For"
      operator: "Equal"
      value: "dep"
      effect: "NoSchedule"
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: For
                operator: In
                values:
                  - dep
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app.kubernetes.io/name
              operator: In
              values:
              - rabbitmq
          topologyKey: kubernetes.io/hostname
        weight: 100
```

> **Note:**\
> `spec.persistence.storage` must not be less than `disk_free_limit.absolute` (2GB by default) to avoid triggering a disk alarm, which would block the publisher.

> **Note:**\
> The metrics exporter is enabled by default. The Cluster Operator deploys
> RabbitMQ with the `rabbitmq_prometheus` plugin activated, exposing Prometheus
> metrics on port `15692` (`/metrics`).

Apply the created manifest:

```bash
kubectl apply -f rabbitmq.yaml
```

To install Docs, specify the corresponding parameters:

```yaml
connections:
  amqpType: rabbitmq
  amqpHost: rabbitmq
  amqpPort: "5672"
  amqpVhost: "/"
  amqpUser: onlyoffice
  amqpProto: amqp
  amqpExistingSecret: rabbitmq-default-user
  amqpSecretKeyName: password
```

## Deploy Valkey

[Valkey Cluster Operator](https://github.com/valkey-io/valkey-operator)

Install the Valkey Cluster Operator:

```bash
helm repo add valkey https://valkey.io/valkey-helm/
helm repo update

helm install valkey --version 0.5.0 valkey/valkey-operator \
  --namespace valkey-operator-system \
  --create-namespace
```

For more details, see [here](https://github.com/valkey-io/valkey-helm/tree/main/valkey-operator).

Create a `valkey.yaml` manifest with the following content:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: docs-valkey-cluster
type: Opaque
stringData:
  valkey-password: "password-not-for-real-secret"

---
apiVersion: valkey.io/v1alpha1
kind: ValkeyCluster
metadata:
  name: valkey
spec:
  shards: 3
  replicas: 1
  persistence:
    size: 10Gi
    storageClassName: PERSISTENT_STORAGE_CLASS
  users:
    - name: default
      passwordSecret:
        name: docs-valkey-cluster
        keys: [valkey-password]
      permissions: "+@all ~* &*"
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 4000m
      memory: 4Gi
  scheduling:
    nodeSelector:
      For: dep
    tolerations:
      - key: "For"
        operator: "Equal"
        value: "dep"
        effect: "NoSchedule"
    node:
      spread:
        shard:
          mode: Preferred
  exporter:
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 2000m
        memory: 2Gi
```

> **Note:**\
> In the `docs-valkey-cluster` secret, specify your own password for the `valkey-password` key.

> **Note:**\
> The metrics exporter is enabled by default. Each pod runs a `metrics-exporter`
> sidecar exposing Prometheus metrics on port `9121` (`/metrics`). To disable it, set
> `spec.exporter.enabled: false` in the `ValkeyCluster` manifest.

Apply the created manifest:

```bash
kubectl apply -f valkey.yaml
```

To install Docs, specify the corresponding parameters:

```yaml
connections:
  redisConnectorName: redis
  redisUser: default
  ## Only DB 0 is used in the cluster version
  redisDBNum: "0"
  redisClusterNodes:
  - valkey-valkey:6379
  redisExistingSecret: docs-valkey-cluster
  redisSecretKeyName: valkey-password
  redisNoPass: false
```
