# Apache Polaris Iceberg Catalog

使用 Apache Polaris 作为 Iceberg REST Catalog，Iceberg 的表数据和元数据文件保存在 MinIO 中。

Polaris 自身的 catalog/principal/view 等注册信息不再存放在 `/tmp`，而是持久化到项目已有 PostgreSQL 服务中。

## 环境变量

- `POLARIS_VERSION`：Polaris 服务镜像版本。
- `POLARIS_HTTP_PORT`：宿主机映射到 Polaris `8181` 端口的端口。
- `POLARIS_REALM`：Polaris realm，默认 `POLARIS`。
- `POLARIS_CLIENT_ID` / `POLARIS_CLIENT_SECRET`：访问 Polaris REST API 的 OAuth2 client credentials。
- `POLARIS_CATALOG_NAME`：Polaris 中创建的 Iceberg catalog 名称，默认 `iceberg`。
- `POLARIS_JDBC_URL`：Polaris 元数据使用的 JDBC 地址，默认使用已有 PostgreSQL。
- `POLARIS_JDBC_USER`：Polaris 元数据使用的 PostgreSQL 用户。
- `POLARIS_JDBC_PASSWORD`：Polaris 元数据使用的 PostgreSQL 密码。
- `POLARIS_MINIO_USER` / `POLARIS_MINIO_PASSWORD`：Polaris 访问 MinIO 时使用的凭证。
- `ICEBERG_MINIO_BUCKET`：Iceberg warehouse 使用的 MinIO bucket。
- `ICEBERG_MINIO_REGION`：MinIO S3 兼容层使用的 region。

## 默认配置

- Polaris REST Catalog 地址：`http://<host>:${POLARIS_HTTP_PORT}`
- Trino 中的 Iceberg catalog 名称：`iceberg`
- Warehouse：`s3://iceberg`
- MinIO 端点：`http://minio:9000`
- 访问模式：`path-style-access=true`
- Polaris 元数据：PostgreSQL

## 使用说明

### 1. 手动创建 MinIO bucket

MinIO 不会自动创建 Polaris/Iceberg 使用的 bucket。先启动 MinIO：

```bash
docker compose up -d minio
```

通过 MinIO 控制台 `http://<host>:9001` 创建名为 `iceberg` 的 bucket。

也可以在宿主机使用 `mc`：

```bash
mc alias set minio http://localhost:9000 admin admin888
mc mb --ignore-existing minio/iceberg
```

`mc alias set` 的作用是为 `mc` 客户端注册一个名为 `minio` 的别名，后续 `mc` 命令都通过这个别名访问对应的 MinIO 服务，而不需要每次都重复输入地址和账号密码。

### 2. 启动依赖服务

确认 bucket 已创建后，启动 PostgreSQL 和 MinIO：

```bash
docker compose up -d minio postgres
```

### 3. 手动初始化 Polaris

`docker-compose.yml` 中已经不再包含 `polaris-bootstrap` 和 `polaris-init`，因此 Polaris 的 realm 初始化和 catalog 创建都需要手动执行。

#### 3.1 手动执行 bootstrap

先确认 PostgreSQL 已启动并健康，然后在宿主机手动运行 Polaris 管理工具：

```bash
NETWORK=${COMPOSE_PROJECT_NAME:-fs-project}_default

docker run --rm \
  --network "${NETWORK}" \
  -e POLARIS_PERSISTENCE_TYPE=relational-jdbc \
  -e POLARIS_PERSISTENCE_RELATIONAL_JDBC_DATABASE_TYPE=postgresql \
  -e QUARKUS_DATASOURCE_DB_KIND=postgresql \
  -e QUARKUS_DATASOURCE_JDBC_URL=jdbc:postgresql://postgres:5432/postgres \
  -e QUARKUS_DATASOURCE_USERNAME=postgres \
  -e QUARKUS_DATASOURCE_PASSWORD=admin888 \
  apache/polaris-admin:${POLARIS_VERSION:-1.7.0} \
  bootstrap --realm=POLARIS --credential=POLARIS,root,admin888
```

如果你的 `COMPOSE_PROJECT_NAME`、PostgreSQL 账号密码或 Polaris realm 与默认值不同，请同步修改上面的命令。

#### 3.2 启动 Polaris

```bash
docker compose up -d polaris
```

#### 3.3 手动创建 catalog

以下命令需要宿主机安装 `jq`，用于从 OAuth2 响应中提取 access token。

Polaris 启动后，先在宿主机获取 OAuth2 token：

```bash
POLARIS_HOST=http://localhost:8181
CLIENT_ID=root
CLIENT_SECRET=admin888
REALM=POLARIS

TOKEN=$(curl -sS --fail-with-body \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -H "Polaris-Realm: ${REALM}" \
  -d grant_type=client_credentials \
  -d scope=PRINCIPAL_ROLE:ALL \
  "${POLARIS_HOST}/api/catalog/v1/oauth/tokens" | jq -r .access_token)
```

创建 `iceberg` catalog：

```bash
curl -sS --fail-with-body -X POST \
  "${POLARIS_HOST}/api/management/v1/catalogs" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Polaris-Realm: ${REALM}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{
    "catalog": {
      "name": "iceberg",
      "type": "INTERNAL",
      "readOnly": false,
      "properties": {
        "default-base-location": "s3://iceberg"
      },
      "storageConfigInfo": {
        "storageType": "S3",
        "endpoint": "http://localhost:9000",
        "endpointInternal": "http://minio:9000",
        "pathStyleAccess": true,
        "region": "us-east-1"
      }
    }
  }'
```

如果 catalog 已经存在，创建命令会返回冲突，可以跳过创建，继续执行授权：

```bash
curl -sS --fail-with-body -X PUT \
  "${POLARIS_HOST}/api/management/v1/catalogs/iceberg/catalog-roles/catalog_admin/grants" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Polaris-Realm: ${REALM}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{"type":"catalog","privilege":"CATALOG_MANAGE_CONTENT"}'
```

手动完成初始化后，再启动 Trino：

```bash
docker compose up -d trino
```

### 4. 在 Trino 中管理 Iceberg 视图

进入 Trino CLI：

```bash
docker compose exec trino trino
```

先创建 schema：

```sql
CREATE SCHEMA iceberg.default;
```

然后可以创建普通视图：

```sql
CREATE VIEW iceberg.default.user_view AS
SELECT * FROM iceberg.default.users WHERE status = 1;
```

Polaris 通过 Iceberg REST Catalog 支持 view 管理；JDBC catalog 不支持 view，因此这里不要改用 Trino 的 JDBC Iceberg catalog。

## 生产环境说明

当前配置把 Polaris 元数据写入项目已有 PostgreSQL 的默认 `postgres` 数据库，适合本仓库的单机/测试环境。

生产环境建议：

- 为 Polaris 创建独立数据库和独立数据库账号。
- 使用独立、受控的 `POLARIS_CLIENT_ID` / `POLARIS_CLIENT_SECRET`。
- 为 PostgreSQL 和 MinIO 配置备份与高可用。
- 不要将 Polaris 的 `8181` 端口直接暴露到公网。
