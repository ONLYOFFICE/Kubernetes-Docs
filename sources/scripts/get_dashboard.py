import sys
import json
import logging
import requests
import os
from kubernetes import client, config

dashboards_list_path = '/scripts/dashboards.json'
dashboard_label = os.environ.get('SIDECAR_DASHBOARD_LABEL', 'grafana_dashboard')
dashboard_label_value = os.environ.get('SIDECAR_DASHBOARD_LABEL_VALUE', '1')

pathNS = '/run/secrets/kubernetes.io/serviceaccount/namespace'
with open(pathNS, "r") as f_ns:
    ns = f_ns.read().strip()


def init_logger(name):
    logger = logging.getLogger(name)
    formatter = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    logger.setLevel(logging.DEBUG)
    stdout = logging.StreamHandler()
    stdout.setFormatter(logging.Formatter(formatter))
    stdout.setLevel(logging.DEBUG)
    logger.addHandler(stdout)


def read_dashboards_list():
    try:
        with open(dashboards_list_path, "r") as f_list:
            dashboards = json.load(f_list)
        logger_dashboard.info(f'Successfully read dashboards list from {dashboards_list_path}')
        return dashboards
    except Exception as msg_read:
        logger_dashboard.error(f'Failed to read dashboards list from {dashboards_list_path}... {msg_read}')
        sys.exit(1)


def download_dashboard(url):
    try:
        resp = requests.get(url, timeout=30)
        resp.raise_for_status()
        content = resp.text
        content = content.replace("${DS_PROMETHEUS}", "Prometheus")
        content = content.replace("$DS_PROMETHEUS", "Prometheus")
        logger_dashboard.info(f'Successfully downloaded dashboard from {url}')
        return content
    except Exception as msg_download:
        logger_dashboard.error(f'Failed to download dashboard from {url}... {msg_download}')
        return None


def apply_configmap(cm_name, content):
    v1 = client.CoreV1Api()
    data = {f"{cm_name}.json": content}
    try:
        existing = v1.read_namespaced_config_map(name=cm_name, namespace=ns)
        labels = existing.metadata.labels or {}
        labels[dashboard_label] = dashboard_label_value
        cm = client.V1ConfigMap(
            metadata=client.V1ObjectMeta(
                name=cm_name,
                namespace=ns,
                labels=labels,
                annotations=existing.metadata.annotations,
            ),
            data=data,
        )
        v1.replace_namespaced_config_map(name=cm_name, namespace=ns, body=cm)
        logger_dashboard.info(f'ConfigMap "{cm_name}" successfully updated in namespace "{ns}"')
    except client.exceptions.ApiException as msg_get_cm:
        if msg_get_cm.status == 404:
            logger_dashboard.warning(f'The {cm_name} ConfigMap was not found')
            logger_dashboard.info('A new ConfigMap will be created with the received dashboard...')
            try:
                cm = client.V1ConfigMap(
                    metadata=client.V1ObjectMeta(
                        name=cm_name,
                        namespace=ns,
                        labels={dashboard_label: dashboard_label_value},
                    ),
                    data=data,
                )
                v1.create_namespaced_config_map(namespace=ns, body=cm)
                logger_dashboard.info(f'ConfigMap "{cm_name}" successfully created in namespace "{ns}"')
            except Exception as msg_create_cm:
                logger_dashboard.error(
                                f'Could not creat "{cm_name}" ConfigMap... {msg_create_cm}')
                sys.exit(1)
        else:
            logger_dashboard.error(
                f'Could not get information about the existing "{cm_name}" ConfigMap... {msg_get_cm}')
            sys.exit(1)


init_logger('dashboard')
logger_dashboard = logging.getLogger('dashboard.ds')
config.load_incluster_config()

failed = False
for item in read_dashboards_list():
    content = download_dashboard(item["url"])
    if content is None:
        failed = True
        continue
    apply_configmap(item["name"], content)

if failed:
    sys.exit(1)
