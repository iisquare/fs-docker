# Trino

同类组件中，Apache Calcite是一个可嵌入的SQL查询优化框架，
为其他系统提供SQL解析、优化能力，本身不存储数据、不执行计算，
被Flink、Drill、Hive等众多知名项目使用，构建自定义的SQL查询引擎或数据库。
Trino是一个完整的分布式SQL查询引擎，作为独立服务集群部署，用户通过客户端连接使用。

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
htpasswd -c -B -C 10 ./service/trino/etc/password.db your_username

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

## 选型建议

### 数据源视图与物化视图支持对比

| 数据源/连接器      | 普通视图支持情况             | 物化视图支持情况 | 关键说明                                                     |
| :----------------- | :--------------------------- | :--------------- | :----------------------------------------------------------- |
| **Hive**           | ✅ 支持（**可创建&读取**）    | ✅ 支持           | 最常用后端，支持在Trino中创建视图。 **注意**：读取Hive原有视图需配置 `hive.views-execution.enabled=true`。 |
| **Iceberg**        | ✅ 支持（**可创建&读取**）    | ✅ 支持           | 官方推荐的Lakehouse方案，视图元数据存储在Iceberg自身。       |
| **Delta Lake**     | ✅ 支持（**可创建&读取**）    | ✅ 支持           | 与Hive/Iceberg类似，可作为视图的存储和读取后端。             |
| **PostgreSQL**     | ✅ 仅支持**读取**（不能创建） | ❌ 不支持         | Trino会将PostgreSQL中的原生视图识别为普通表进行查询。        |
| **MySQL**          | ✅ 仅支持**读取**（不能创建） | ❌ 不支持         | 同上，视图逻辑必须用MySQL的SQL方言编写。                     |
| **Oracle**         | ✅ 仅支持**读取**（不能创建） | ❌ 不支持         | 同上，仅支持查询源端的视图定义。                             |
| **Elasticsearch**  | ❌ 不支持                     | ❌ 不支持         | 无SQL视图概念，也无法作为物化视图的存储目标。                |
| **Nessie Catalog** | ❌ 不支持（无法创建）         | ❌ 不支持         | 官方明确指出当前版本不支持视图管理功能。                     |

### Iceberg元数据管理及Trino物化视图支持对比

| 特性维度                  | Apache Polaris                                               | Hive Metastore (HMS)                         | iceberg-rest-fixture                          |
| :------------------------ | :----------------------------------------------------------- | :------------------------------------------- | :-------------------------------------------- |
| **项目定位**              | 云原生、开源的企业级Iceberg元数据目录                        | 传统的Hive元数据服务                         | 用于测试和开发的REST API模拟工具              |
| **核心协议**              | **Iceberg REST API**                                         | **Thrift** 协议（基于JVM）                   | **Iceberg REST API**                          |
| **主要用途**              | 生产环境下的统一元数据治理、多引擎互操作                     | 管理Hive及部分Spark等生态的元数据            | 开发测试、接口验证、快速搭建演示环境          |
| **凭证下发**              | **支持**，可下发临时、表级凭证，更安全                       | **不支持**                                   | **不支持**                                    |
| **访问控制**              | 细粒度的角色和权限控制 (RBAC)                                | 有限的、基于Hadoop生态的访问控制             | **无** (模拟工具)                             |
| **多引擎支持**            | **优秀**。任何支持Iceberg REST API的引擎（如Spark, Flink, DuckDB）均可无缝连接 | **受限**。主要面向JVM生态，非JVM客户端需代理 | **良好**。可用于测试任何支持REST API的客户端  |
| **数据版本控制**          | **不支持**（分支/标签等特性由 Nessie 等项目提供）            | **不支持**                                   | **不支持**                                    |
| **联邦查询**              | **支持**。可将其作为统一入口，联邦查询外部HMS等数据源        | **不支持**                                   | **不支持**                                    |
| **对Trino物化视图的支持** | **❌ 暂不支持** （但架构具备潜力，未来可能支持）              | **✅ 支持** （当前唯一可行的选择）            | **❌ 不支持** （定位为测试工具，不具备此功能） |
| **生产就绪度**            | **高**。Apache顶级项目，企业级特性丰富                       | **高**。技术成熟，但应对现代湖仓有局限       | **低**。专为测试环境设计                      |



## 参考
- [Trino documentation](https://trino.io/docs/current/index.html)
- [Presto安装部署详细说明](https://blog.csdn.net/jsbylibo/article/details/107821214)
