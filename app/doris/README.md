# apache doris

Doris单节点集群。

## 安装配置

### 环境准备

- 关闭 swap 分区
```
swapoff -a # 临时关闭
```

- 增加虚拟内存区域
```
cat >> /etc/sysctl.conf << EOF
vm.max_map_count = 2000000
EOF

# Take effect immediately
sysctl -p
```

### 配置文件

- 修改配置
```
下载对应版本的二进制安装包，提取fe.conf和bg.conf文件到对应目录下。
priority_networks = 127.0.0.0/24
```

- 注册服务
```
mysql -h 127.0.0.1 -P 9030 -uroot -p
SHOW BACKENDS\G;
ALTER SYSTEM ADD BACKEND "127.0.0.1:9050";
```

## 如何使用

## [整体架构](https://doris.apache.org/zh-CN/docs/dev/gettingStarted/what-is-apache-doris)

### Frontend (FE)

主要负责接收用户请求、查询解析和规划、元数据管理以及节点管理。

### Backend (BE)

主要负责数据存储和查询计划的执行。数据会被切分成数据分片（Shard），在 BE 中以多副本方式存储。


## 参考链接

- [Apache Doris Docker 部署](https://doris.apache.org/zh-CN/docs/2.0/install/cluster-deployment/run-docker-cluster)
