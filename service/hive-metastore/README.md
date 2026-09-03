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
-Ddatanucleus.rdbms.mysql.characterSet=utf8mb4
-Ddatanucleus.rdbms.mysql.collation=utf8mb4_bin
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
  CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;

CREATE USER IF NOT EXISTS 'hive'@'%' IDENTIFIED BY 'admin888';

GRANT ALL PRIVILEGES ON `hive_metastore`.* TO 'hive'@'%';

FLUSH PRIVILEGES;
```

请确保这里的数据库名、账号和密码与 `.env` 中的以下变量一致：

```env
HIVE_METASTORE_DB_NAME=hive_metastore
HIVE_METASTORE_DB_USER=hive
HIVE_METASTORE_DB_PASSWORD=admin888
HIVE_METASTORE_JDBC_URL=jdbc:mysql://mysql:3306/hive_metastore?createDatabaseIfNotExist=true&useSSL=false&allowPublicKeyRetrieval=true&useUnicode=true&characterEncoding=UTF-8&connectionCollation=utf8mb4_bin
```

## MySQL 字符集与中文名称问题

Hive Metastore 在 MySQL 下由 DataNucleus 自动建表时，如果不显式指定字符集，生成出来的表会使用
`latin1` / `latin1_bin`，而不是数据库的 `utf8mb4` 默认字符集。因此可能出现：

- 数据库是 `utf8mb4`，但自动创建的表是 `latin1`；
- 创建、查询或删除中文库名、中文表名、中文视图名时变慢甚至超时；
- 中文分区值、中文注释显示为 `??` 或被截断。

原因是：JDBC URL 里的 `useUnicode`、`characterEncoding` 只控制 JDBC 连接会话的编码，不能决定
DataNucleus 生成的 `CREATE TABLE` 使用什么 `CHARSET` 和 `COLLATE`。表结构的字符集由下面两个
DataNucleus 参数控制：

```text
-Ddatanucleus.rdbms.mysql.characterSet=utf8mb4
-Ddatanucleus.rdbms.mysql.collation=utf8mb4_bin
```

因此需要同时配置：

1. `SERVICE_OPTS` 中加入上述两个 DataNucleus 参数；
2. JDBC URL 中加入 `characterEncoding=UTF-8&connectionCollation=utf8mb4_bin`；
3. 初始化数据库时使用 `utf8mb4` 和 `utf8mb4_bin`。

`useUnicode=true` 可以保留，但在 MySQL Connector/J 8 中它不是关键参数，真正影响连接层字符集的是
`characterEncoding` 和 `connectionCollation`。

注意：修改以上配置只会影响以后新建的表。已经自动创建的 `latin1` 表不会自动变成 `utf8mb4`，需要
手动迁移，或者在元数据不重要时删除数据库后让 Hive 重新创建。

如果只需解决中文视图名删除超时，可以对关键表执行：

```sql
ALTER TABLE `hive_metastore`.`DBS`
  CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;

ALTER TABLE `hive_metastore`.`TBLS`
  CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
```

如果需要保留现有元数据并完整迁移所有表，请先备份数据库，然后在维护窗口执行字符集转换。

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
`hive-metastore` 或 `iceberg_hms.properties` 中。若要把数据固定写入某个 bucket，本项目约定：
不在 `CREATE SCHEMA` 上指定 `location`，而是在 `CREATE MATERIALIZED VIEW` 上统一指定。

原因：`CREATE SCHEMA ... WITH (location = 's3://...')` 会让 Hive Metastore 尝试创建该外部目录，
这需要 HMS 具备 S3A 文件系统支持；当前 HMS 只接入 MySQL 元数据，未配置 S3A，因此会报：

```text
Failed to create external path s3://iceberg/dataset for database dataset ...
```

所以 schema 只负责逻辑命名空间，数据落到哪个 bucket 由物化视图的 `location` 决定：

```sql
CREATE SCHEMA iceberg_hms.dataset;

CREATE MATERIALIZED VIEW iceberg_hms.dataset.v1
WITH (location = 's3://iceberg/dataset/v1/')
AS
SELECT ...;
```

普通 Iceberg 表同理：在 `CREATE TABLE ... WITH (location = ...)` 上指定，不要在 schema 上指定。

强制限制（可选）：通过 MinIO 权限把账号限制在固定的 bucket 中

即使 SQL 中的 `location` 写错，也可以从 MinIO 侧强制 Trino 只能访问 `iceberg` bucket。做法是创建一个
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

CREATE MATERIALIZED VIEW iceberg_hms.dataset.v3
WITH (location = 's3://iceberg/dataset/v3')
AS
SELECT ...
```

说明：`CREATE SCHEMA` 不指定 location 时，Hive Metastore 会给它一个默认的本地 warehouse 路径
`file:/opt/hive/data/warehouse`。因此创建物化视图时必须用 `location` 把 storage table 显式指到
MinIO；否则 storage table 会继承 schema 的 `file:` 路径，而 `iceberg_hms` 只启用了 S3，会报：

```text
No factory for location: file:/opt/hive/data/warehouse/...
```

不要在 `CREATE SCHEMA` 上指定 location（那会触发 HMS 创建 S3A 外部目录并报
`Failed to create external path ...`），统一在物化视图上指定即可。

物化视图还支持 `partitioning`、`format` 等属性，例如：

```sql
CREATE MATERIALIZED VIEW iceberg_hms.dataset.v3
WITH (
  location = 's3://iceberg/dataset/v3',
  partitioning = ARRAY['created_time']
)
AS
SELECT ...
```

`CREATE MATERIALIZED VIEW` 只保存定义，不会立即写入数据；执行 `REFRESH MATERIALIZED VIEW`
后才会真正物化，这时 MinIO 中才会出现 `data/` 目录：

```sql
REFRESH MATERIALIZED VIEW iceberg_hms.dataset.v3;
```

在第一次 `REFRESH` 之前，storage table 是空的（stale），Trino 查询该视图时会回退为直接执行其
定义里的源查询（inline），所以 `SELECT` 能返回结果，但 MinIO 里还没有物化数据。

跨 catalog 支持：当前 Trino 版本（483）已支持 Iceberg 物化视图的 `AS` 查询引用其他 catalog 的
表，例如 MySQL、其他文档库。这类跨 catalog 的物化视图刷新时走全量刷新（full refresh），不会做
增量刷新。示例：

```sql
CREATE OR REPLACE MATERIALIZED VIEW iceberg_hms.dataset.v1
WITH (
  location = 's3://iceberg/dataset/v1/',
  partitioning = ARRAY['id']
)
AS
SELECT
  t1.id,
  t1.name,
  t2.method
FROM "本地文档"."fs_bi_excel"."t1" t1
LEFT JOIN "mysql"."fs_project"."fs_bi_data_api" t2 ON t1.id = t2.id;

REFRESH MATERIALIZED VIEW iceberg_hms.dataset.v1;
```
