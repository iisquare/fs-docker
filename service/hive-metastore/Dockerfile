ARG HIVE_VERSION

FROM apache/hive:${HIVE_VERSION}

USER root

# 官方镜像默认不带 PostgreSQL JDBC 驱动，这里在构建镜像时补入。
ADD https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.4/postgresql-42.7.4.jar \
    /opt/hive/lib/postgresql-42.7.4.jar

RUN chmod 0644 /opt/hive/lib/postgresql-42.7.4.jar && \
    chown hive:hive /opt/hive/lib/postgresql-42.7.4.jar

USER hive

EXPOSE 9083
