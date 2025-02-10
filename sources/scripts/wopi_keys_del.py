import os
import logging
from kubernetes import client

wopi_secret_name = os.environ.get('WOPI_SECRET_NAME')
wopi_old_secret_name = os.environ.get('WOPI_OLD_SECRET_NAME')

k8s_host = os.environ["KUBERNETES_SERVICE_HOST"]
api_server = f'https://{k8s_host}'
pathCrt = '/run/secrets/kubernetes.io/serviceaccount/ca.crt'
pathToken = '/run/secrets/kubernetes.io/serviceaccount/token'
pathNS = '/run/secrets/kubernetes.io/serviceaccount/namespace'

with open(pathToken, "r") as f_tok:
    token = f_tok.read()

with open(pathNS, "r") as f_ns:
    ns = f_ns.read()

configuration = client.Configuration()
configuration.ssl_ca_cert = pathCrt
configuration.host = api_server
configuration.verify_ssl = True
configuration.debug = False
configuration.api_key = {"authorization": "Bearer " + token}
client.Configuration.set_default(configuration)
v1 = client.CoreV1Api()


def init_logger(name):
    logger = logging.getLogger(name)
    formatter = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    logger.setLevel(logging.DEBUG)
    stdout = logging.StreamHandler()
    stdout.setFormatter(logging.Formatter(formatter))
    stdout.setLevel(logging.DEBUG)
    logger.addHandler(stdout)
    logger.info('Running a script to delete a Secret with WOPI keys\n')


def delete_secret(secret_name):
    try:
        v1.delete_namespaced_secret(name=secret_name, namespace=ns)
        logger_pod_ds.info(f'Secret "{secret_name}" has been successfully deleted')
    except Exception as msg_delete_secret:
        logger_pod_ds.error(f'Failed to delete the "{secret_name}" Secret... {msg_delete_secret}')


def get_secret_keys():
    try:
        v1.read_namespaced_secret(name=wopi_secret_name, namespace=ns)
        logger_pod_ds.info(f'The existing {wopi_secret_name} Secret with WOPI keys has been found and will be deleted')
    except client.exceptions.ApiException as msg_get_secret:
        if msg_get_secret.status == 404:
            logger_pod_ds.warning(f'The {wopi_secret_name} Secret with WOPI keys was not found')
        else:
            logger_pod_ds.warning(f'Could not get information about the existing "{wopi_secret_name}" Secret with WOPI keys... {msg_get_secret}')
    except Exception as e:
        logger_pod_ds.error(f'Could not get information about the existing "{wopi_secret_name}" Secret with old WOPI keys... {e}')
    else:
        delete_secret(wopi_secret_name)


def get_secret_old_keys():
    try:
        v1.read_namespaced_secret(name=wopi_old_secret_name, namespace=ns)
        logger_pod_ds.info(f'The existing {wopi_old_secret_name} Secret with old WOPI keys has been found and will be deleted')
    except client.exceptions.ApiException as msg_get_secret:
        if msg_get_secret.status == 404:
            logger_pod_ds.warning(f'The {wopi_old_secret_name} Secret with old WOPI keys was not found')
        else:
            logger_pod_ds.warning(f'Could not get information about the existing "{wopi_old_secret_name}" Secret with old WOPI keys... {msg_get_secret}')
    except Exception as e:
        logger_pod_ds.error(f'Could not get information about the existing "{wopi_old_secret_name}" Secret with old WOPI keys... {e}')
    else:
        delete_secret(wopi_old_secret_name)


init_logger('wopi')
logger_pod_ds = logging.getLogger('wopi.keys')
get_secret_keys()
get_secret_old_keys()
