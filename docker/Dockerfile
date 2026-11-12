# image unique pour spark-master, spark-worker et notebook
# base : jupyter/pyspark-notebook (python + spark 3.5 + jupyterlab déjà installés)
FROM jupyter/pyspark-notebook:latest

USER root

# connecteurs java que spark doit avoir dans son classpath :
#  - spark-sql-kafka : lire/écrire kafka depuis spark (structured streaming)
#  - kafka-clients, commons-pool2, token-provider : ses dépendances
#  - postgresql : le driver JDBC pour écrire le gold dans le warehouse
# on lit la version exacte de spark et de scala dans le nom du jar spark-core
# -> le connecteur colle toujours à la version de spark de l'image
RUN set -eux; \
    CORE_JAR=$(ls ${SPARK_HOME}/jars/ | grep '^spark-core_'); \
    SCALA_V=$(echo "$CORE_JAR" | sed -E 's/spark-core_([0-9.]+)-.*/\1/'); \
    SPARK_V=$(echo "$CORE_JAR" | sed -E 's/spark-core_[0-9.]+-([0-9.]+)\.jar/\1/'); \
    echo "spark=${SPARK_V} scala=${SCALA_V}"; \
    M=https://repo1.maven.org/maven2; \
    cd ${SPARK_HOME}/jars; \
    wget -q ${M}/org/apache/spark/spark-sql-kafka-0-10_${SCALA_V}/${SPARK_V}/spark-sql-kafka-0-10_${SCALA_V}-${SPARK_V}.jar; \
    wget -q ${M}/org/apache/spark/spark-token-provider-kafka-0-10_${SCALA_V}/${SPARK_V}/spark-token-provider-kafka-0-10_${SCALA_V}-${SPARK_V}.jar; \
    wget -q ${M}/org/apache/kafka/kafka-clients/3.4.1/kafka-clients-3.4.1.jar; \
    wget -q ${M}/org/apache/commons/commons-pool2/2.11.1/commons-pool2-2.11.1.jar; \
    wget -q ${M}/org/postgresql/postgresql/42.7.4/postgresql-42.7.4.jar; \
    ls -1 ${SPARK_HOME}/jars | grep -E 'kafka|pool2|postgresql'

USER ${NB_UID}

# libs python : client kafka, appels http, client HDFS (webhdfs), driver postgres
RUN pip install --no-cache-dir \
      'kafka-python>=2.0.3' \
      requests==2.32.3 \
      hdfs==2.7.3 \
      psycopg2-binary==2.9.10

# vérif au build : si pyspark ou les libs ne s'importent pas, le build échoue tout de suite.
# dans cette image, pyspark n'est PAS dans le PYTHONPATH pendant le build : c'est un script de
# démarrage de jupyter (before-notebook.d) qui l'ajoute au lancement. on le reconstruit à la main ici.
RUN export PYTHONPATH="${SPARK_HOME}/python:$(ls ${SPARK_HOME}/python/lib/py4j-*-src.zip)" && \
    python -c "import pyspark, kafka, hdfs, psycopg2, requests; print('pyspark', pyspark.__version__, '| kafka-python', kafka.__version__)"
