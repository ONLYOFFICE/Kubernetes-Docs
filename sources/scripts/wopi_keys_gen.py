import os
import sys
import logging
import base64
import subprocess
from kubernetes import client

wopi_secret_name = os.environ.get('WOPI_SECRET_NAME')
wopi_old_secret_name = os.environ.get('WOPI_OLD_SECRET_NAME')

generate_keys = True

wopi_private_key_gen = '/scripts/wopi_private_gen.key'
wopi_private_key = '/scripts/wopi_private.key'
wopi_public_key_gen = '/scripts/wopi_public_gen.key'
wopi_public_key = '/scripts/wopi_public.key'
wopi_modulus_key = '/scripts/wopi_modulus.key'
wopi_exponent_key = '/scripts/wopi_exponent.key'

keys_paths = {
    "WOPI_PRIVATE_KEY": wopi_private_key,
    "WOPI_PUBLIC_KEY": wopi_public_key,
    "WOPI_MODULUS_KEY": wopi_modulus_key,
    "WOPI_EXPONENT_KEY": wopi_exponent_key
}
keys_old_paths = {
    "WOPI_PRIVATE_KEY_OLD": wopi_private_key,
    "WOPI_PUBLIC_KEY_OLD": wopi_public_key,
    "WOPI_MODULUS_KEY_OLD": wopi_modulus_key,
    "WOPI_EXPONENT_KEY_OLD": wopi_exponent_key
}

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
    logger.info('Running a script to get information about a Secret with WOPI keys\n')


def wopi_keys_gen():
    global generate_keys
    generate_keys = False
    try:
        exponent_cmd = r'{printf "%s\\n", $0}'
        private_key_gen = ["/bin/bash", "-c", f"openssl genpkey -algorithm RSA -outform PEM -out {wopi_private_key_gen}"]
        public_key_gen = ["/bin/bash", "-c", f"openssl rsa -RSAPublicKey_out -in {wopi_private_key_gen} -outform \"MS PUBLICKEYBLOB\" -out {wopi_public_key_gen}"]
        modulus_key_gen = ["/bin/bash", "-c", f"openssl rsa -pubin -inform \"MS PUBLICKEYBLOB\" -modulus -noout -in {wopi_public_key_gen} | sed 's/Modulus=//' | xxd -r -p | openssl base64 -A > {wopi_modulus_key}"]
        exponent_key_gen = ["/bin/bash", "-c", f"openssl rsa -pubin -inform \"MS PUBLICKEYBLOB\" -text -noout -in {wopi_public_key_gen} | grep -oP '(?<=Exponent: )\d+' > {wopi_exponent_key}"]
        private_key = ["/bin/bash", "-c", f"awk '{exponent_cmd}' {wopi_private_key_gen} > {wopi_private_key}"]
        public_key = ["/bin/bash", "-c", f"openssl base64 -in {wopi_public_key_gen} -A > {wopi_public_key}"]
        all_cmd = [private_key_gen, public_key_gen, modulus_key_gen, exponent_key_gen, private_key, public_key]
        all_status = []
        for cmd in all_cmd:
            process = subprocess.Popen(cmd)
            process.wait()
            code = process.returncode
            if code != 0:
                all_status.append(code)
        array_size = len(all_status)
        if array_size > 0:
            logger_pod_ds.error('Error when trying to generate keys')
            sys.exit(1)
        else:
            logger_pod_ds.info('Keys have been successfully generated')
    except Exception as msg_check_dir_access:
        logger_pod_ds.error(f'Failed to execute key generation commands... {msg_check_dir_access}\n')
        sys.exit(1)


def create_data_from_keys(keys_dict, secret_name):
    try:
        data = {}
        for key_name, key_path in keys_dict.items():
            with open(key_path, 'rb') as f:
                file_content = f.read()
                data[key_name] = base64.b64encode(file_content).decode()
        logger_pod_ds.info(f'The "data" field for the "{secret_name}" Secret has been successfully generated')
        return data
    except Exception as msg_create_data:
        logger_pod_ds.error(f'Error forming "data" for the "{secret_name}" Secret... {msg_create_data}')


def create_secret(path, secret_name):
    if generate_keys:
        wopi_keys_gen()
    try:
        data = create_data_from_keys(path, secret_name)
        secret = client.V1Secret(
            metadata=client.V1ObjectMeta(name=secret_name),
            type="Opaque",
            data=data
        )
        v1.create_namespaced_secret(namespace=ns, body=secret)
        logger_pod_ds.info(f'Secret "{secret_name}" has been successfully created')
    except Exception as msg_create_secret:
        logger_pod_ds.error(f'Failed to create a Secret "{secret_name}"... {msg_create_secret}')


def get_secret_keys():
    try:
        v1.read_namespaced_secret(name=wopi_secret_name, namespace=ns)
        logger_pod_ds.info(f'An existing Secret "{wopi_secret_name}" has been found, it will be used')
    except client.exceptions.ApiException as msg_get_secret:
        if msg_get_secret.status == 404:
            logger_pod_ds.warning(f'The {wopi_secret_name} Secret with WOPI keys was not found')
            logger_pod_ds.info('A new secret will be created with the generated keys...')
            create_secret(keys_paths, wopi_secret_name)
        else:
            logger_pod_ds.warning(f'Could not get information about the existing "{wopi_secret_name}" Secret with WOPI keys...')
            logger_pod_ds.info('A new secret will be created with the generated keys...')
            create_secret(keys_paths, wopi_secret_name)


def get_secret_old_keys():
    try:
        v1.read_namespaced_secret(name=wopi_old_secret_name, namespace=ns)
        logger_pod_ds.info(f'An existing Secret "{wopi_old_secret_name}" has been found, it will be used')
    except client.exceptions.ApiException as msg_get_secret:
        if msg_get_secret.status == 404:
            logger_pod_ds.warning(f'The {wopi_old_secret_name} Secret with old WOPI keys was not found')
            logger_pod_ds.info('A new secret will be created with the generated keys...')
            create_secret(keys_old_paths, wopi_old_secret_name)
        else:
            logger_pod_ds.warning(f'Could not get information about the existing "{wopi_old_secret_name}" Secret with old WOPI keys...')
            logger_pod_ds.info('A new secret will be created with the generated keys...')
            create_secret(keys_old_paths, wopi_old_secret_name)


init_logger('wopi')
logger_pod_ds = logging.getLogger('wopi.keys')
get_secret_keys()
get_secret_old_keys()
