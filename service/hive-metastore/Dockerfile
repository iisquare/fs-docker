ARG HIVE_VERSION

FROM apache/hive:${HIVE_VERSION}

USER root

# 官方镜像默认不带 MySQL JDBC 驱动，这里在构建镜像时补入。
ADD https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.4.0/mysql-connector-j-8.4.0.jar \
    /opt/hive/lib/mysql-connector-j-8.4.0.jar

USER hive

EXPOSE 9083
