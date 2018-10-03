#!/usr/bin/env bash

export USER_ID=$(id -u)
export GROUP_ID=$(id -g)
envsubst < /passwd.template > ${NSS_WRAPPER_PASSWD}
export LD_PRELOAD=libnss_wrapper.so
export PYSPARK_DRIVER_PYTHON=jupyter
export PYSPARK_DRIVER_PYTHON_OPTS="notebook --ip='*' --allow-root"

# Run pyspark with spark-cassandra-connector
pyspark --packages datastax:spark-cassandra-connector:2.3.1-s_2.11

