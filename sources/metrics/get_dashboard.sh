#!/bin/bash
wget https://grafana.com/api/dashboards/1860/revisions/22/download -O dashboard-node-exporter.json
wget https://grafana.com/api/dashboards/8588/revisions/1/download -O dashboard-deployment.json
wget https://grafana.com/api/dashboards/11835/revisions/1/download -O dashboard-redis.json
wget https://grafana.com/api/dashboards/10991/revisions/8/download -O dashboard-rabbitmq.json
wget https://grafana.com/api/dashboards/9628/revisions/6/download -O dashboard-postgresql.json
wget https://grafana.com/api/dashboards/9614/revisions/1/download -O dashboard-nginx-ingress.json
sed -i 's/${DS_PROMETHEUS}/Prometheus/' *.json
kubectl create configmap dashboard-node-exporter --from-file=./dashboard-node-exporter.json
kubectl create configmap dashboard-deployment --from-file=./dashboard-deployment.json
kubectl create configmap dashboard-redis --from-file=./dashboard-redis.json
kubectl create configmap dashboard-rabbitmq --from-file=./dashboard-rabbitmq.json
kubectl create configmap dashboard-postgresql --from-file=./dashboard-postgresql.json
kubectl create configmap dashboard-nginx-ingress --from-file=./dashboard-nginx-ingress.json
kubectl create configmap dashboard-documentserver --from-file=./sources/metrics/documentserver-statsd-exporter.json
kubectl create configmap dashboard-documentserver --from-file=./sources/metrics/kubernetes-cluster-resourses.json
