FROM openjdk:8u181-jdk-slim-stretch

ENV SPARK_VERSION=2.3.1
ARG SPARK_CHECKSUM=e87499e5417a64341cbda25e087632dd9f6ce7ad249dfeba47d9d02a51305fc2

ENV CONDA_VERSION=3
ARG CONDA_CHECKSUM=80ecc86f8c2f131c5170e43df489514f80e3971dd105c075935470bbf2476dea

RUN update-ca-certificates -f \
  && apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y \
    curl \
    vim \
    libnss-wrapper \
    gettext-base \
  && apt-get clean

ENV USER_NAME=notebook NSS_WRAPPER_PASSWD=/tmp/passwd NSS_WRAPPER_GROUP=/tmp/group
RUN touch ${NSS_WRAPPER_PASSWD} ${NSS_WRAPPER_GROUP} && \
    chgrp 0 ${NSS_WRAPPER_PASSWD} ${NSS_WRAPPER_GROUP} && \
    chmod g+rw ${NSS_WRAPPER_PASSWD} ${NSS_WRAPPER_GROUP}
COPY conf/passwd.template /passwd.template

# Spark
WORKDIR /tmp
ENV SPARK_HOME=/opt/spark
RUN curl -sLO "https://www.apache.org/dyn/mirrors/mirrors.cgi?action=download&filename=spark/spark-$SPARK_VERSION/spark-$SPARK_VERSION-bin-hadoop2.7.tgz" && \
   echo "$SPARK_CHECKSUM  spark-$SPARK_VERSION-bin-hadoop2.7.tgz" | sha256sum --check && \
   tar xvzf "spark-$SPARK_VERSION-bin-hadoop2.7.tgz" && \
   mv spark-$SPARK_VERSION-bin-hadoop2.7 $SPARK_HOME && \
   rm /tmp/spark-$SPARK_VERSION-bin-hadoop2.7.tgz
ENV PATH="$SPARK_HOME/bin:$PATH"

# Miniconda
ENV CONDA_DIR /opt/miniconda
RUN curl -sSL "https://repo.continuum.io/miniconda/Miniconda$CONDA_VERSION-latest-Linux-x86_64.sh" -o miniconda.sh && \
    echo "$CONDA_CHECKSUM  miniconda.sh" | sha256sum --check && \
    chmod 755 miniconda.sh && \
    ./miniconda.sh -b -p $CONDA_DIR && \
    rm ./miniconda.sh
ENV PATH="$CONDA_DIR/bin:$PATH"

# Install conda dependencies
RUN conda install -y python=3 --quiet \
        && conda install jupyter -y --quiet \
        && conda install -c conda-forge xgboost -y --quiet \
        && conda install -c conda-forge python-couchdb -y --quiet \
        && conda install -c conda-forge python-confluent-kafka -y --quiet \
        && conda install -c conda-forge mpl-probscale -y --quiet \
        && conda install -c anaconda seaborn -y --quiet \
        && conda install -c conda-forge cassandra-driver -y --quiet \
        && conda install -c conda-forge pyspark -y --quiet \
        && conda install -c conda-forge findspark -y --quiet \
        && conda update conda \
        && conda clean --all --yes

# Set up Ivy for use by Spark.
RUN mkdir -p /var/cache/ivy
COPY conf/spark-defaults.conf /opt/spark/conf/

# Add the config file.
ADD jupyter_notebook_config.py /.jupyter/

# Smoketest the spark installation with and pre-warm the packages cache for the spark connector.
COPY smoketest-spark.py /tmp/
RUN spark-submit --packages datastax:spark-cassandra-connector:2.3.1-s_2.11 /tmp/smoketest-spark.py

# Set correct permissions
RUN mkdir /.local/ && \
    chmod -R 775 /.local/ && \
    mkdir /opt/notebooks && \
    chmod -R 775 /opt/notebooks/ && \
    chmod -R 775 /.jupyter && \
    find /var/cache/ivy -type d -print0 | xargs -0 chmod 755 && \
    find /var/cache/ivy -type f -print0 | xargs -0 chmod 644 && \
    chmod 1777 /var/cache/ivy/cache

ADD start_jupyter_cassandra.sh /spark/start_jupyter_cassandra.sh
RUN chmod 755 /spark/start_jupyter_cassandra.sh
EXPOSE 8888

ENTRYPOINT ["/spark/start_jupyter_cassandra.sh"]

