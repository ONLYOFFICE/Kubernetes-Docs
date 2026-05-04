## Configure converter auto-scaling based on RabbitMQ queue size

In addition to CPU and memory based autoscaling, the chart supports scaling Converter replicas based on the size of a RabbitMQ queue. This is useful when conversion tasks accumulate in the queue and you want consumers to scale up automatically to drain it faster.

The chart's HPA template already supports external metrics through the `converter.autoscaling.customMetricsType` value. To use queue-based autoscaling, you need a metrics provider in your cluster that exposes the RabbitMQ queue length as a Kubernetes external metric.

### Prerequisites

- A running RabbitMQ by bitnami with the `rabbitmq_prometheus` plugin enabled. The plugin is enabled by default. Also you can check that plugin is enabled with command:

```bash
kubectl exec rabbitmq-0 -- rabbitmq-plugins list | grep prometheus
```

- DocumentServer chart installed.

### Step 1. Install kube-prometheus-stack

Install a minimal Prometheus setup. Grafana, Alertmanager, and other components are disabled because they are not required for autoscaling.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kps prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --set grafana.enabled=false \
  --set alertmanager.enabled=false \
  --set nodeExporter.enabled=false \
  --set kubeApiServer.enabled=false \
  --set kubelet.enabled=false \
  --set kubeControllerManager.enabled=false \
  --set kubeScheduler.enabled=false \
  --set kubeProxy.enabled=false \
  --set kubeEtcd.enabled=false \
  --set coreDns.enabled=false \
  --set defaultRules.create=false
```

### Step 2. Create a ServiceMonitor for RabbitMQ

Tell Prometheus to scrape RabbitMQ metrics. Create a file `rabbitmq-servicemonitor.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: rabbitmq
  namespace: <rabbitmq-namespace>
  labels:
    release: kps
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: <rabbitmq-release-name>
  namespaceSelector:
    matchNames:
    - <rabbitmq-namespace>
  endpoints:
  - port: metrics
    path: /metrics/per-object
    interval: 15s
```

Replace `<rabbitmq-namespace>` with the namespace where RabbitMQ is deployed and `<rabbitmq-release-name>` with the name of the Helm release used to install RabbitMQ (e.g. `rabbitmq` if you ran `helm install rabbitmq bitnami/rabbitmq`).

Apply:

```bash
kubectl apply -f rabbitmq-servicemonitor.yaml
```

### Step 3. Install Prometheus Adapter

Prometheus Adapter exposes Prometheus metrics through the Kubernetes external metrics API, which the HPA can consume.

Create a file `adapter-values.yaml`:

```yaml
prometheus:
  url: http://kps-kube-prometheus-stack-prometheus.monitoring.svc
  port: 9090

rules:
  default: false
  external:
  - seriesQuery: 'rabbitmq_queue_messages_ready{queue!=""}'
    resources:
      template: <<.Resource>>
    name:
      matches: "^(.*)$"
      as: "${1}"
    metricsQuery: 'sum by (queue) (rabbitmq_queue_messages_ready{<<.LabelMatchers>>})'
```

Install:

```bash
helm install prometheus-adapter prometheus-community/prometheus-adapter \
  -n monitoring \
  -f adapter-values.yaml
```

### Step 4. Verify the metric is available

Make sure RabbitMQ has at least one queue with messages, if you already deploy Kubernetes-Docs, just run:

```bash
kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1/namespaces/<namespace>/rabbitmq_queue_messages_ready?labelSelector=queue%3Dconverttask6"
```

Output should be like this:

```bash
{"kind":"ExternalMetricValueList","apiVersion":"external.metrics.k8s.io/v1beta1","metadata":{},"items":[{"metricName":"rabbitmq_queue_messages_ready","metricLabels":{"queue":"converttask6"},"timestamp":"2026-05-04T12:25:38Z","value":"0"}]}
```

A successful response returns a numeric `value`. If `items` is empty or you get an error, check:

- The Prometheus UI for the `rabbitmq_queue_messages_ready` metric
- The Prometheus Adapter logs: `kubectl logs -n monitoring deploy/prometheus-adapter`
- That the `external.metrics.k8s.io` APIService is registered: `kubectl get apiservice | grep external.metrics`

### Step 5. Re-deploy DocumentServer with the new autoscaling configuration

Create a file `converter-autoscaling-values.yaml` with the queue-based autoscaling parameters:

```yaml
converter:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 20
    targetCPU:
      enabled: true
      utilizationPercentage: 75
    targetMemory:
      enabled: true
      utilizationPercentage: 80
    customMetricsType:
      - type: External
        external:
          metric:
            name: rabbitmq_queue_messages_ready
            selector:
              matchLabels:
                queue: converttask6
          target:
            type: AverageValue
            averageValue: "1"
    behavior:
      scaleDown:
        stabilizationWindowSeconds: 30
        policies:
        - type: Pods
          value: 1
          periodSeconds: 15
      scaleUp:
        stabilizationWindowSeconds: 0
        policies:
        - type: Pods
          value: 1
          periodSeconds: 15
```

Apply the values to your existing release:

```bash
helm upgrade documentserver onlyoffice/docs \
  --reuse-values \
  -f converter-autoscaling-values.yaml
```

To learn more about how the scaling algorithm works, please refer to the official [HPA algorim details documentation](https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/#algorithm-details).

When CPU, memory, and queue metrics are all configured, the HPA picks the maximum desired replica count across all metrics. This ensures the Converter scales up regardless of which signal indicates pressure.

> ***Tip***
> For reference, here is an example converter hpa configuration. Use it if you need modify hpa manually.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: custom-converter-hpa
  namespace: "<NAMESPACE>"
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: converter
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 75
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  - external:
      metric:
        name: rabbitmq_queue_messages_ready
        selector:
          matchLabels:
            queue: converttask6
      target:
        averageValue: "1"
        type: AverageValue
    type: External
  behavior:
    scaleDown:
      policies:
      - periodSeconds: 15
        type: Pods
        value: 1
      stabilizationWindowSeconds: 30
    scaleUp:
      policies:
      - periodSeconds: 15
        type: Pods
        value: 1
      stabilizationWindowSeconds: 0
```
