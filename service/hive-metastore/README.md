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

## MinIO bucket 说明

MinIO 中的 `iceberg` bucket 是对象存储里的一个顶层命名空间。Iceberg 表的实际数据文件和
metadata 文件都存放在这个 bucket 下，例如：

```text
s3://iceberg/dataset/v1-5360741b29e04ab4976efbf39535fffa/metadata/00000-xxxx.metadata.json
s3://iceberg/dataset/v1-5360741b29e04ab4976efbf39535fffa/data/xxxx.parquet
```

Hive Metastore 只保存库、表、列等逻辑元数据，以及指向这些 S3 路径的 `location`。它自身不会读写
Iceberg 的数据文件和 metadata 文件，因此 HMS 配置里没有 bucket 参数。

同理，Trino 的 `iceberg_hms.properties` 里也没有 bucket 参数。该 catalog 只负责：

- 通过 `hive.metastore.uri` 连接 Hive Metastore；
- 通过 `s3.endpoint`、`s3.aws-access-key`、`s3.aws-secret-key` 访问 MinIO；
- 实际写入哪个 bucket，由 Iceberg 表/库的 `location` 决定。

因此 `.env` 中的 `ICEBERG_MINIO_BUCKET=iceberg` 只是当前约定的 bucket 名称，没有自动接到
`hive-metastore` 或 `iceberg_hms.properties` 中。若要把数据固定写入某个 bucket，需要显式指定位置：

方式一：在 Hive Metastore 的 `SERVICE_OPTS` 中设置默认 warehouse 目录：

```text
-Dhive.metastore.warehouse.dir=s3://iceberg/warehouse
```

这样，所有未显式指定 `location` 的 schema 和 table，都会落到该 warehouse 目录下。

方式二：在 Trino 中创建 schema/table 时显式指定 `location`：

```sql
CREATE SCHEMA iceberg_hms.dataset
WITH (location = 's3://iceberg/dataset');

CREATE TABLE iceberg_hms.dataset.v3 (...)
WITH (location = 's3://iceberg/dataset/v3');
```

显式 `location` 的优先级高于 HMS 的 warehouse 目录。

方式三：通过 MinIO 权限把账号限制在固定的 bucket 中（推荐用于强制执行）

即使前面两种方式不配置，也可以从 MinIO 侧强制 Trino 只能访问 `iceberg` bucket。做法是创建一个
只授权 `iceberg` bucket 的 MinIO 用户，然后把 Trino 的 S3 凭证从当前的 `admin` 换成这个专用用户。

先准备策略文件 `iceberg-only-policy.json`：

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListMultipartUploadParts",
        "s3:AbortMultipartUpload"
      ],
      "Resource": [
        "arn:aws:s3:::iceberg",
        "arn:aws:s3:::iceberg/*"
      ]
    }
  ]
}
```

在宿主机使用 `mc` 创建并绑定策略：

```bash
mc alias set minio http://localhost:9000 admin admin888

mc admin policy create minio iceberg-only iceberg-only-policy.json
mc admin user add minio iceberg-trino 'change-this-strong-password'
mc admin policy attach minio iceberg-only --user iceberg-trino
```

然后把 Trino 的 `iceberg_hms.properties` 中的 S3 凭证替换为这个专用用户：

```properties
s3.aws-access-key=iceberg-trino
s3.aws-secret-key=change-this-strong-password
```

这样即使 SQL 中把 `location` 写成其他 bucket，Trino 也会因 MinIO 返回 `AccessDenied` 而无法写入，
从而在存储层强制限制只能使用 `iceberg` bucket。

注意：bucket 本身需要在 MinIO 中提前创建，MinIO 不会自动创建 bucket。

在 Trino 中创建物化视图：

```sql
CREATE SCHEMA iceberg_hms.dataset;

CREATE MATERIALIZED VIEW iceberg_hms.dataset.v3 AS
SELECT ...
```
