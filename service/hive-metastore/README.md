# Hive Metastore

独立部署的 Apache Hive Metastore，仅作为 Iceberg 元数据服务使用。

该服务不依赖 HDFS、YARN、HiveServer2，元数据复用项目内已有的 MySQL 实例：

- 服务名：`hive-metastore`
- 端口：`9083`
- 元数据库：`${HIVE_METASTORE_DB_NAME}`
- 元数据库账号：`${HIVE_METASTORE_DB_USER}`
- JDBC URL：`${HIVE_METASTORE_JDBC_URL}`
- JDBC 驱动：MySQL

## 配置说明

服务基于官方 `apache/hive` 镜像构建，并在镜像中补充 MySQL JDBC 驱动，然后通过 `SERVICE_NAME=metastore` 启动 standalone Metastore。

主要 JDBC 配置由 `SERVICE_OPTS` 注入：

```text
-Djavax.jdo.option.ConnectionDriverName=com.mysql.cj.jdbc.Driver
-Djavax.jdo.option.ConnectionURL=${HIVE_METASTORE_JDBC_URL}
-Djavax.jdo.option.ConnectionUserName=${HIVE_METASTORE_DB_USER}
-Djavax.jdo.option.ConnectionPassword=${HIVE_METASTORE_DB_PASSWORD}
-Ddatanucleus.schema.autoCreateAll=true
```

## 手动初始化 MySQL

先确保 MySQL 已启动：

```bash
cd /mnt/d/htdocs/fs-docker
docker compose up -d mysql
```

进入 MySQL：

```bash
docker compose exec mysql mysql -uroot -p${MYSQL_ROOT_PASSWORD}
```

然后执行以下 SQL，创建 Hive Metastore 使用的数据库和账号：

```sql
CREATE DATABASE IF NOT EXISTS `hive_metastore`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'hive'@'%' IDENTIFIED BY 'admin888';

GRANT ALL PRIVILEGES ON `hive_metastore`.* TO 'hive'@'%';

FLUSH PRIVILEGES;
```

请确保这里的数据库名、账号和密码与 `.env` 中的以下变量一致：

```env
HIVE_METASTORE_DB_NAME=hive_metastore
HIVE_METASTORE_DB_USER=hive
HIVE_METASTORE_DB_PASSWORD=admin888
HIVE_METASTORE_JDBC_URL=jdbc:mysql://mysql:3306/hive_metastore?createDatabaseIfNotExist=true&useSSL=false&allowPublicKeyRetrieval=true
```

## Trino 接入

新增的 `iceberg_hms` catalog 使用该 Metastore：

```properties
connector.name=iceberg
iceberg.catalog.type=hive_metastore
hive.metastore.uri=thrift://hive-metastore:9083
```

在 Trino 中创建物化视图：

```sql
CREATE SCHEMA iceberg_hms.dataset;

CREATE MATERIALIZED VIEW iceberg_hms.dataset.v3 AS
SELECT ...
```
