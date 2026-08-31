# Trino

## 使用说明

### 安装配置

- 登录用户

```bash
# 生成 Keystore 文件 (用于 HTTPS)
source ~/envs/jdk-17
keytool -genkeypair -alias trino -keyalg RSA -keystore ./service/trino/etc/keystore.jks \
  -storepass your_keystore_pass -keypass your_key_pass \
  -validity 365 -keysize 2048 \
  -dname "CN=localhost, OU=Dev, O=IISquare, L=City, ST=State, C=CN"

# 生成密码文件
sudo apt install apache2-utils
htpasswd -B -C 10 ./service/trino/etc/password.db your_username

# 修改配置
cp ./service/trino/config.properties.example ./service/trino/config.properties
```

- 配置文件

默认在/etc/trino中，若需要覆盖，可在docker-compose.yml文件中单独挂载。

### 常用命令
- CLI
```
sudo docker-compose exec trino trino --server https://localhost:8443 --user root --password --insecure
sudo docker-compose exec trino trino --catalog mysql --schema fs_project
```
- 帮助
```
help;
```
- 数据源
```
show catalogs;
use mysql.default;
show schemas;
show tables;
```

### Superset集成
- 驱动
```
pip install sqlalchemy-trino
```
- 连接
```
trino://{username}:{password}@{hostname}:{port}/{catalog}
trino://admin@trino:8080/mysql
```

### Elasticsearch数据源

- 数组
```
POST /索引名称/_mapping
{
  "_meta": {
    "trino": {
      "字段名称": {
        "isArray": true
      }
    }
  }
}
```

## 参考
- [Trino documentation](https://trino.io/docs/current/index.html)
- [Presto安装部署详细说明](https://blog.csdn.net/jsbylibo/article/details/107821214)
