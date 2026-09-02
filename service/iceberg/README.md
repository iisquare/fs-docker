# Iceberg REST Catalog

独立的 Apache Iceberg REST Catalog 服务，数据文件通过 MinIO 存储。

## 环境变量

- `ICEBERG_VERSION`：Iceberg REST Catalog 镜像版本。
- `ICEBERG_HTTP_PORT`：宿主机的 HTTP 端口，映射到容器的 `8181`。
- `ICEBERG_MINIO_BUCKET`：Iceberg warehouse 使用的 MinIO bucket。
- `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD`：MinIO 访问凭证。

## 默认配置

- REST Catalog 地址：`http://<host>:8181`
- Warehouse：`s3://iceberg`
- MinIO 端点：`http://minio:9000`
- 访问模式：`path-style-access=true`

## 使用说明

### 1. 手动创建 MinIO bucket

MinIO 服务本身不会自动创建 Iceberg 使用的 bucket。请先启动 MinIO：

```bash
docker compose up -d minio
```

然后通过 MinIO 控制台（`http://<host>:9001`）创建一个名为 `iceberg` 的 bucket。

也可以在宿主机安装 `mc` 后手动创建：

```bash
mc alias set minio http://localhost:9000 admin admin888
mc mb --ignore-existing minio/iceberg
```

### 2. 启动 Iceberg

确认 bucket 已创建后，再启动 Iceberg：

```bash
docker compose up -d iceberg
```

Iceberg 的元数据与数据文件都会保存在 MinIO 的 `iceberg` bucket 中。
