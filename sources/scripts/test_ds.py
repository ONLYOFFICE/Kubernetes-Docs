import os
import sys
import subprocess
import time
import logging

url = 'http://docservice:8000/healthcheck'

redisConnectorName = os.environ.get('REDIS_CONNECTOR_NAME')
redisHost = os.environ.get('REDIS_SERVER_HOST')
redisPort = os.environ.get('REDIS_SERVER_PORT')
redisUser = os.environ.get('REDIS_SERVER_USER')
redisPassword = os.environ.get('REDIS_SERVER_PWD')
redisDBNum = os.environ.get('REDIS_SERVER_DB_NUM')
redisConnectTimeout = 15
if os.environ.get('REDIS_CLUSTER_NODES'):
    redisClusterNodes = list(os.environ.get('REDIS_CLUSTER_NODES').split(" "))
    redisClusterNode = redisClusterNodes[0].split(":")[0]
    redisClusterPort = redisClusterNodes[0].split(":")[1]
if redisConnectorName == 'ioredis':
    redisSentinelGroupName = os.environ.get('REDIS_SENTINEL_GROUP_NAME')

dbType = os.environ.get('DB_TYPE')
dbHost = os.environ.get('DB_HOST')
dbPort = int(os.environ.get('DB_PORT'))
dbUser = os.environ.get('DB_USER')
dbPassword = os.environ.get('DB_PWD')
dbName = os.environ.get('DB_NAME')
dbConnectTimeout = 15
dbTable = ['task_result', 'doc_changes']

brokerType = os.environ.get('AMQP_TYPE')
brokerProto = os.environ.get('AMQP_PROTO')
brokerHost = os.environ.get('AMQP_HOST')
brokerPort = os.environ.get('AMQP_PORT')
brokerUser = os.environ.get('AMQP_USER')
brokerPassword = os.environ.get('AMQP_PWD')
brokerVhost = os.environ.get('AMQP_VHOST')

storageS3 = os.environ.get('STORAGE_S3')

total_result = {}


def init_logger(name):
    logger = logging.getLogger(name)
    formatter = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    logger.setLevel(logging.DEBUG)
    stdout = logging.StreamHandler()
    stdout.setFormatter(logging.Formatter(formatter))
    stdout.setLevel(logging.DEBUG)
    logger.addHandler(stdout)
    logger.info('Running a script to test the availability of DocumentServer and dependencies\n')


def get_redis_status():
    import redis
    global rc
    try:
        rc = redis.Redis(
            host=redisHost,
            port=redisPort,
            db=redisDBNum,
            password=redisPassword,
            username=redisUser,
            socket_connect_timeout=redisConnectTimeout,
            retry_on_timeout=True
        )
        rc.ping()
    except Exception as msg_redis:
        logger_test_ds.error(f'Failed to check the availability of the Redis Standalone... {msg_redis}\n')
        total_result['CheckRedis'] = 'Failed'
    else:
        logger_test_ds.info('Successful connection to Redis Standalone')
        return rc.ping()


def get_redis_cluster_status():
    from redis.cluster import RedisCluster as Redis
    from redis.cluster import ClusterNode
    global rc
    try:
        nodes = [ClusterNode(redisClusterNode, redisClusterPort)]
        rc = Redis(
            startup_nodes=nodes,
            username=redisUser,
            password=redisPassword,
            socket_connect_timeout=redisConnectTimeout,
            retry_on_timeout=True
        )
        rc.ping()
    except Exception as msg_redis:
        logger_test_ds.error(f'Failed to check the availability of the Redis Cluster... {msg_redis}\n')
        total_result['CheckRedis'] = 'Failed'
    else:
        logger_test_ds.info('Successful connection to Redis Cluster')
        return rc.ping()


def get_redis_sentinel_status():
    import redis
    from redis import Sentinel
    global rc
    try:
        sentinel = Sentinel([(redisHost, redisPort)], socket_timeout=redisConnectTimeout)
        master_host, master_port = sentinel.discover_master(redisSentinelGroupName)
        rc = redis.Redis(
            host=master_host,
            port=master_port,
            db=redisDBNum,
            password=redisPassword,
            username=redisUser,
            socket_connect_timeout=redisConnectTimeout,
            retry_on_timeout=True
        )
        rc.ping()
    except Exception as msg_redis:
        logger_test_ds.error(f'Failed to check the availability of the Redis Sentinel... {msg_redis}\n')
        total_result['CheckRedis'] = 'Failed'
    else:
        logger_test_ds.info('Successful connection to Redis Sentinel')
        return rc.ping()


def check_redis_key():
    try:
        rc.set('testDocsServer', 'ok')
        test_key = rc.get('testDocsServer').decode('utf-8')
        logger_test_ds.info(f'Test Key: {test_key}')
    except Exception as msg_check_redis:
        logger_test_ds.error(f'Error when trying to write a key to Redis... {msg_check_redis}\n')
        total_result['CheckRedis'] = 'Failed'
    else:
        rc.delete('testDocsServer')
        logger_test_ds.info('The test key was successfully recorded and deleted from Redis\n')
        rc.close()
        total_result['CheckRedis'] = 'Success'


def check_redis():
    logger_test_ds.info('Checking Redis availability...')
    if redisConnectorName == 'redis' and not os.environ.get('REDIS_CLUSTER_NODES'):
        if get_redis_status() is True:
            check_redis_key()
    elif redisConnectorName == 'redis' and os.environ.get('REDIS_CLUSTER_NODES'):
        if get_redis_cluster_status() is True:
            check_redis_key()
    elif redisConnectorName == 'ioredis':
        if get_redis_sentinel_status() is True:
            check_redis_key()


def check_db_postgresql(tbl_dict):
    import psycopg2
    try:
        dbc = psycopg2.connect(
            host=dbHost,
            port=dbPort,
            database=dbName,
            password=dbPassword,
            user=dbUser,
            connect_timeout=dbConnectTimeout
        )
        logger_test_ds.info(f'Successful connection to the "{dbName}" database')
        for tbl in dbTable:
            with dbc.cursor() as cursor:
                cursor.execute(f"SELECT EXISTS (SELECT * FROM information_schema.tables WHERE table_name='{tbl}');")
                table_exists = cursor.fetchone()[0]
                if table_exists is True:
                    logger_test_ds.info(f'The table "{tbl}" exists in the "{dbName}" database')
                    tbl_dict[tbl] = 'Exists'
                else:
                    logger_test_ds.error(f'The table "{tbl}" does not exists in the "{dbName}" database')
                    tbl_dict[tbl] = 'NotExists'
    except Exception as msg_check_dblist:
        logger_test_ds.error(f'Error when trying to get a list of DS tables in the "{dbName}" database... {msg_check_dblist}\n')
        total_result['CheckPostgreSQL'] = 'Failed'
    else:
        dbc.close()
        logger_test_ds.info(f'Check of DS tables in "{dbName}" database has been finished\n')
        if 'NotExists' in tbl_dict.values():
            total_result['CheckPostgreSQL'] = 'Failed'
        else:
            total_result['CheckPostgreSQL'] = 'Success'


def check_db_mysql(tbl_dict):
    import pymysql
    try:
        dbc = pymysql.connect(
            host=dbHost,
            port=dbPort,
            database=dbName,
            password=dbPassword,
            user=dbUser,
            connect_timeout=dbConnectTimeout
        )
        logger_test_ds.info(f'Successful connection to the "{dbName}" database')
        for tbl in dbTable:
            with dbc.cursor() as cursor:
                cursor.execute(f"SELECT EXISTS (SELECT * FROM information_schema.tables WHERE TABLE_NAME='{tbl}' AND TABLE_SCHEMA='{dbName}');")
                table_exists = cursor.fetchone()[0]
                if table_exists == 1:
                    logger_test_ds.info(f'The table "{tbl}" exists in the "{dbName}" database')
                    tbl_dict[tbl] = 'Exists'
                else:
                    logger_test_ds.error(f'The table "{tbl}" does not exists in the "{dbName}" database')
                    tbl_dict[tbl] = 'NotExists'
    except Exception as msg_check_dblist:
        logger_test_ds.error(f'Error when trying to get a list of DS tables in the "{dbName}" database... {msg_check_dblist}\n')
        total_result['CheckMySQL'] = 'Failed'
    else:
        dbc.close()
        logger_test_ds.info(f'Check of DS tables in "{dbName}" database has been finished\n')
        if 'NotExists' in tbl_dict.values():
            total_result['CheckMySQL'] = 'Failed'
        else:
            total_result['CheckMySQL'] = 'Success'


def check_db():
    logger_test_ds.info('Checking database availability...')
    tbl_result = {}
    if dbType == 'postgres':
        check_db_postgresql(tbl_result)
    elif dbType == 'mysql' or dbType == 'mariadb':
        check_db_mysql(tbl_result)


def check_mq_rabbitmq():
    import pika
    try:
        mqp = pika.URLParameters(f'{brokerProto}://{brokerUser}:{brokerPassword}@{brokerHost}:{brokerPort}{brokerVhost}')
        mqc = pika.BlockingConnection(mqp)
        mq_connect_status = mqc.is_open
        logger_test_ds.info('Successful connection to RabbitMQ')
    except Exception as msg_check_rabbitmq:
        logger_test_ds.error(f'Failed to check the availability of the RabbitMQ... {msg_check_rabbitmq}\n')
        total_result['CheckRabbitMQ'] = 'Failed'
    else:
        if mq_connect_status is True:
            try:
                mqchannel = mqc.channel()
                mqchannel.queue_declare(queue='testDocsServer')
            except Exception as msg_check_rabbitmq_queue:
                logger_test_ds.error(f'Error when trying to create a test queue in RabbitMQ... {msg_check_rabbitmq_queue}\n')
                total_result['CheckRabbitMQ'] = 'Failed'
            else:
                mqchannel.queue_delete(queue='testDocsServer')
                logger_test_ds.info('The test queue was successfully created and deleted in RabbitMQ\n')
                mqc.close()
                total_result['CheckRabbitMQ'] = 'Success'
        else:
            logger_test_ds.error('Error when trying to create a test queue in RabbitMQ\n')


def check_mq_activemq():
    from proton.handlers import MessagingHandler
    from proton.reactor import Container
    activemq_proto = os.environ.get('AMQP_PROTO')
    if activemq_proto == 'amqp+ssl':
        activemq_proto = 'amqps'

    class ActivemqConnect(MessagingHandler):
        activemq_connected = None

        def on_start(self, event):
            event.container.connect(f'{activemq_proto}://{brokerHost}:{brokerPort}', user=brokerUser, password=brokerPassword)

        def on_connection_opened(self, event):
            event.connection.close()
            ActivemqConnect.activemq_connected = True

    try:
        Container(ActivemqConnect()).run()
    except Exception as msg_check_activemq:
        logger_test_ds.error(f'Failed to check the availability of the ActiveMQ... {msg_check_activemq}\n')
        total_result['CheckActiveMQ'] = 'Failed'
    else:
        if ActivemqConnect.activemq_connected is True:
            logger_test_ds.info('Successful connection to ActiveMQ\n')
            total_result['CheckActiveMQ'] = 'Success'
        else:
            logger_test_ds.error(f'Failed to check the availability of the ActiveMQ. Incorrect username-password pair\n')
            total_result['CheckActiveMQ'] = 'Failed'


def check_mq():
    logger_test_ds.info('Checking Broker availability...')
    if brokerType == 'rabbitmq':
        check_mq_rabbitmq()
    elif brokerType == 'activemq':
        from func_timeout import func_timeout, FunctionTimedOut
        try:
            activemq_return_status = func_timeout(15, check_mq_activemq)
        except FunctionTimedOut:
            logger_test_ds.error('Failed to check the availability of the ActiveMQ within 15 seconds. Terminated...\n')
            total_result['CheckActiveMQ'] = 'Failed'


def check_dir_access():
    logger_test_ds.info('Checking the availability of shared storage...')
    try:
        dir_create = ['mkdir', '/ds/test/App_Data/cache/files/testds']
        dir_delete = ['rm', '-rf', '/ds/test/App_Data/cache/files/testds']
        all_cmd = [dir_create, dir_delete]
        all_status = []
        for cmd in all_cmd:
            process = subprocess.Popen(cmd)
            process.wait()
            code = process.returncode
            if code != 0:
                all_status.append(code)
        array_size = len(all_status)
        if array_size > 0:
            logger_test_ds.error('Failed when trying to write and delete a test file to the "cache/files" directory\n')
            total_result['CheckDir'] = 'Failed'
        else:
            logger_test_ds.info('The test file was successfully written and deleted to the "cache/files" directory\n')
            total_result['CheckDir'] = 'Success'
    except Exception as msg_check_dir_access:
        logger_test_ds.error(f'Failed when trying to write a test file to the "cache/files" directory... {msg_check_dir_access}\n')
        total_result['CheckDir'] = 'Failed'


def get_ds_status():
    import requests
    from requests.adapters import HTTPAdapter
    logger_test_ds.info('Checking DocumentServer availability...')
    ds_adapter = HTTPAdapter(max_retries=3)
    ds_session = requests.Session()
    ds_session.mount(url, ds_adapter)
    try:
        response = ds_session.get(url, timeout=15)
    except Exception as msg_url:
        logger_test_ds.error(f'Failed to check the availability of the DocumentServer... {msg_url}\n')
        total_result['CheckDS'] = 'Failed'
    else:
        logger_test_ds.info(f'The DocumentServer is available: {response.text}\n')
        if response.text == 'true':
            total_result['CheckDS'] = 'Success'
        else:
            total_result['CheckDS'] = 'Failed'


def total_status():
    logger_test_ds.info('As a result of the check, the following results were obtained:')
    for key, value in total_result.items():
        logger_test_ds.info(f'{key} = {value}')
    if total_result['CheckDS'] != 'Success':
        sys.exit(1)


init_logger('test')
logger_test_ds = logging.getLogger('test.ds')
check_redis()
check_db()
check_mq()
if storageS3 == 'false':
    check_dir_access()
get_ds_status()
total_status()

