# RustFS

基于Rust实现的高性能分布式对象存储，兼容S3 API，采用Apache-2.0协议，替代原MinIO服务。

## 使用说明

- 默认认证
```
rustfsadmin:rustfsadmin
```
- S3 API端口：`9000`，控制台端口：`9001`
- 数据目录：`/data`，日志目录：`/logs`

## 注意事项

- 容器以内置用户`10001:10001`运行，绑定宿主机目录时需保证该用户具备写权限，否则会因权限不足启动失败。
```
mkdir -p ${DATA_DIR}/rustfs/data ${DATA_DIR}/rustfs/logs
chown -R 10001:10001 ${DATA_DIR}/rustfs
```
- 单机单盘部署的`RUSTFS_VOLUMES`固定为`/data`，该形态不支持原地扩容，扩容需通过S3迁移数据。
- 业务桶（如`iceberg`）不会自动创建，需在控制台手动创建或使用S3客户端创建。
- 原MinIO数据目录（`${DATA_DIR}/minio/data`）无法被RustFS直接读取，需通过S3协议迁移：
```
mc alias set minio http://<旧MinIO地址>:9000 <旧账号> <旧密码>
mc alias set rustfs http://<新RustFS地址>:9000 <新账号> <新密码>
mc mirror --overwrite minio/iceberg rustfs/iceberg
```

## 参考连接
- [RustFS官方文档](https://docs.rustfs.com)
- [RustFS代码仓库](https://github.com/rustfs/rustfs)

