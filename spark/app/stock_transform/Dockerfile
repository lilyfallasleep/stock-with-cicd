FROM bitnami/spark:3.5.0

USER root

RUN apt-get update && \
    apt-get install -y python3-pip && \
    pip3 install --upgrade pip && \
    pip3 install minio boto3 pyspark==3.5.0 pandas && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --chown=root:root . /opt/spark-app/
WORKDIR /opt/spark-app

ENV PYSPARK_PYTHON=python3
ENV PYSPARK_DRIVER_PYTHON=python3
ENV AWS_ACCESS_KEY_ID=minio
ENV AWS_SECRET_ACCESS_KEY=minio123
ENV ENDPOINT=http://minio:9000
ENV SPARK_APPLICATION_ARGS="stock-market/NVDA"

CMD ["spark-submit", "--master", "spark://spark-master:7077", "stock_transform.py"]