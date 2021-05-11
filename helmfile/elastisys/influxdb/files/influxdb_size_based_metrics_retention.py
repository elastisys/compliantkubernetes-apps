import logging
import requests
import json
from pandas.io.json import json_normalize
import os
import sys
import urllib.parse

INFLUXDB_HOST = None
INFLUXDB_PORT = None
INFLUXDB_USER = None
INFLUXDB_PASSWORD = None
INFLUXDB_DATABASE = None
INFLUXDB_DATABASE_SIZE_LIMIT_STRING = None
INFLUXDB_MIN_SHARDS_STRING = None
PROMETHEUS_HOST = None
PROMETHEUS_PORT = None
PROMETHEUS_INFLUXDB_METRIC = None
INFLUXDB_DATABASE_SIZE_LIMIT = 0
INFLUXDB_MIN_SHARDS = 1


def create_logger():
    global logger
    logger = logging.getLogger('influxdb_size_based_metrics_retention')
    LOGLEVEL = os.environ.get('LOGLEVEL', 'INFO').upper()
    logger.setLevel(LOGLEVEL)
    ch = logging.StreamHandler()
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s \n%(message)s')
    ch.setFormatter(formatter)
    logger.addHandler(ch)


def get_config():
    global INFLUXDB_HOST
    global INFLUXDB_PORT
    global INFLUXDB_USER
    global INFLUXDB_PASSWORD
    global INFLUXDB_DATABASE
    global INFLUXDB_DATABASE_SIZE_LIMIT_STRING
    global INFLUXDB_MIN_SHARDS_STRING
    global PROMETHEUS_HOST
    global PROMETHEUS_PORT
    global PROMETHEUS_INFLUXDB_METRIC

    # get configuration from environment variables
    try:
        INFLUXDB_HOST = os.environ['INFLUXDB_HOST']
        INFLUXDB_PORT = os.environ['INFLUXDB_PORT']
        INFLUXDB_USER = os.environ['INFLUXDB_USER']
        INFLUXDB_PASSWORD = os.environ['INFLUXDB_PASSWORD']
        INFLUXDB_DATABASE = os.environ['INFLUXDB_DATABASE']
        INFLUXDB_DATABASE_SIZE_LIMIT_STRING = os.environ['INFLUXDB_DATABASE_SIZE_LIMIT']
        INFLUXDB_MIN_SHARDS_STRING = os.environ['INFLUXDB_MIN_SHARDS']
        PROMETHEUS_HOST = os.environ['PROMETHEUS_HOST']
        PROMETHEUS_PORT = os.environ['PROMETHEUS_PORT']
        PROMETHEUS_INFLUXDB_METRIC = os.environ['PROMETHEUS_INFLUXDB_METRIC']
    except KeyError as err:
        logger.error("Environment variable [%s] is not set!", str(err))
        raise err


def parse_numeric_config():
    global INFLUXDB_DATABASE_SIZE_LIMIT
    global INFLUXDB_MIN_SHARDS

    try:
        # Helm converts larges number into scientific notation. Number which is in scientific 
        # notation e.g. 5+e06, can not be parsed by int() but float() can. 
        # And int() can convert floats to int.
        INFLUXDB_DATABASE_SIZE_LIMIT = int(float(INFLUXDB_DATABASE_SIZE_LIMIT_STRING))
        INFLUXDB_MIN_SHARDS = int(INFLUXDB_MIN_SHARDS_STRING)
    except ValueError as err:
        logger.error(
            "Environment variable [%s] could not be parsed to integer!", str(err))
        raise err


def get_db_size():
    try:
        # create request url to query Prometheus regarding the InfluxDB database size
        PROMETHEUS_GET_URL = "http://" + PROMETHEUS_HOST + ":" + \
            PROMETHEUS_PORT + "/api/v1/query?query=" + PROMETHEUS_INFLUXDB_METRIC

        # send the request to Prometheus
        prometheus_response = requests.get(url=PROMETHEUS_GET_URL)
        prometheus_response.raise_for_status()

        # parse the response from Prometheus
        prometheus_query_response_data = prometheus_response.json()
        prometheus_query_response_data_normalized = json_normalize(
            data=prometheus_query_response_data['data']['result'], errors='ignore')
        prometheus_query_response_data_filtered = prometheus_query_response_data_normalized[
            prometheus_query_response_data_normalized['metric.__name__'] == PROMETHEUS_INFLUXDB_METRIC]
        prometheus_metric_row = prometheus_query_response_data_filtered.iloc[0]
        prometheus_metric_value = prometheus_metric_row['value'][1]
        db_size = int(prometheus_metric_value)
        return db_size
    except (IndexError, ValueError):
        logger.error(
            "Could not get the current size of [%s] database.", INFLUXDB_DATABASE)
        logger.debug("Response=[%s]", prometheus_response.content)
        raise ValueError
    except:
        logger.error("Connection to [%s] failed", PROMETHEUS_GET_URL)
        raise ConnectionError


def get_shards():
    try:
        # create request url to query InfluxDB regarding the shards
        INFLUXDB_GET_URL = "http://" + INFLUXDB_HOST + ":" + INFLUXDB_PORT + \
            "/query?u=" + INFLUXDB_USER + "&p=" + INFLUXDB_PASSWORD + "&q=SHOW SHARDS"

        # send the request to InfluxDB
        influxdb_get_response = requests.get(url=INFLUXDB_GET_URL)
        influxdb_get_response.raise_for_status()

        # parse the response from InfluxDB
        data = influxdb_get_response.json()

        # get values
        normalized = json_normalize(
            data=data['results'][0]['series'], record_path='values', errors='ignore')

        # get column names
        colnames = json_normalize(
            data=data['results'][0]['series'][0], record_path='columns')
        columns = []

        for i in range(0, len(colnames.values)):
            columns.append(colnames.values[i, 0])

        normalized.columns = columns

        logger.debug("\nNORMALIZED")
        logger.debug(normalized)

        # filter rows for specified database
        fitered_data = normalized[normalized['database'] == INFLUXDB_DATABASE]

        logger.debug("\nFILTERED")
        logger.debug(fitered_data)

        return fitered_data
    except (KeyError, TypeError, IndexError, ValueError):
        logger.error(
            "Could not get shards of [%s] database.", INFLUXDB_DATABASE)
        logger.debug("Response=[%s]", str(influxdb_get_response.content))
        raise RuntimeError
    except:
        logger.error("Connection to InfluxDB failed")
        logger.debug("Response=[%s]", str(influxdb_get_response.content))
        raise ConnectionError


def get_oldest_shard(shards):
    try:
        sorted_data = shards.sort_values(by=['expiry_time'])

        logger.debug("\nSORTED")
        logger.debug(sorted_data)

        oldest_expiry_row = sorted_data.iloc[0]

        logger.debug("\nOLDEST")
        logger.debug(oldest_expiry_row)

        oldest_expiry_shard_id = oldest_expiry_row['id']
        oldest_expiry_database = oldest_expiry_row['database']
        oldest_expiry_retention_policy = oldest_expiry_row['retention_policy']
        oldest_expiry_time = oldest_expiry_row['expiry_time']

        logger.debug("\nVALUES")
        logger.debug("oldest_expiry_shard_id: %s", str(oldest_expiry_shard_id))
        logger.debug("oldest_expiry_database: %s", str(oldest_expiry_database))
        logger.debug("oldest_expiry_retention_policy: %s",
                     str(oldest_expiry_retention_policy))
        logger.debug("oldest_expiry_time: %s", str(oldest_expiry_time))

        return oldest_expiry_shard_id
    except (KeyError, TypeError, IndexError, ValueError):
        logger.error(
            "Could not get the oldes shard of [%s] database.", INFLUXDB_DATABASE)
        raise RuntimeError


def drop_shard(shard_id):
    query = "DROP SHARD " + str(shard_id)
    INFLUXDB_QUERY = urllib.parse.quote(query)

    INFLUXDB_DROP_URL = "http://" + INFLUXDB_HOST + ":" + INFLUXDB_PORT + \
        "/query?u=" + INFLUXDB_USER + "&p=" + INFLUXDB_PASSWORD + "&q=" + INFLUXDB_QUERY
    logger.debug("\nPOST URL: " + INFLUXDB_DROP_URL)

    try:
        influxdb_drop_response = requests.post(url=INFLUXDB_DROP_URL)
        influxdb_drop_response.raise_for_status()
    except:
        logger.error("Connection to InfluxDB failed")
        logger.debug("Response=[%s]", str(influxdb_drop_response.content))
        raise ConnectionError

    logger.info("Shard with id [%d] dropped successfully.", shard_id)


def main():
    try:
        create_logger()
        get_config()
        parse_numeric_config()

        db_size = get_db_size()

        if db_size <= INFLUXDB_DATABASE_SIZE_LIMIT:
            logger.info("Current size of [%s] database [%d] is within the limit [%d]. No action needed.",
                        INFLUXDB_DATABASE, db_size, INFLUXDB_DATABASE_SIZE_LIMIT)
            quit()

        logger.warning("Current size of [%s] database [%d] is over the limit [%d]! Removing the oldest shard.",
                       INFLUXDB_DATABASE, db_size, INFLUXDB_DATABASE_SIZE_LIMIT)

        shards = get_shards()
        shards_number = shards.shape[0]
        logger.debug("[%s] database consists of [%d] shards.",
                     INFLUXDB_DATABASE, shards_number)

        if (shards_number <= INFLUXDB_MIN_SHARDS):
            logger.warning(
                "Number of shards of [%s] database is not above the minimum number of [%d] shards. Removing the oldest shard aborted!", INFLUXDB_DATABASE, INFLUXDB_MIN_SHARDS)
            quit()

        oldest_shard_id = get_oldest_shard(shards)
        drop_shard(oldest_shard_id)
    except SystemExit as e:
        sys.exit(e)
    except:
        logger.error("Runtime error. Script excecution interrupted!")


if __name__ == "__main__":
    main()
