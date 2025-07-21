FROM apache/airflow:2.10.5-python3.12

USER root

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
         openjdk-17-jre-headless \
  && apt-get autoremove -yqq --purge \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

USER airflow

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# RUN pip uninstall -y apache-airflow apache-airflow-providers-apache-spark
RUN pip install --no-cache-dir "apache-airflow==${AIRFLOW_VERSION}" \
    apache-airflow-providers-apache-spark==4.7.1 \
    apache-airflow-providers-postgres==5.10.1 \
    pyspark==3.5.1