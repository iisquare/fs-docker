# Hive Metastore

独立部署的 Apache Hive Metastore，不依赖 HDFS、YARN、HiveServer2，仅作为 Iceberg 元数据服务使用。

## 配置说明

元数据存储选用PostgreSQL，官方提供的MySQL脚本默认为litin1字符集，需要手动转换为utf8mb4，避免中文表名、视图名在MySQL下删除超时。

## PostgreSQL 初始化

PostgreSQL 数据目录首次启动时不会自动创建 `hive_metastore` 数据库，需要手动创建：

```bash
docker compose up -d postgres
docker compose exec postgres psql -U postgres \
  -c "CREATE DATABASE hive_metastore ENCODING 'UTF8';"
```

数据库创建完成后，再启动 Hive Metastore：

```bash
docker compose build hive-metastore
docker compose up -d hive-metastore
```

Hive Metastore 启动时会通过 `schematool` 自动创建所需的元数据表。

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
这需要 HMS 具备 S3A 文件系统支持；当前 HMS 只接入 PostgreSQL 元数据，未配置 S3A，因此会报：

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
