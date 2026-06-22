# kibana

## 安装运行

### 使用服务账号令牌 (Service Account Token) - 推荐

- 生成服务账号令牌
```
sudo docker-compose exec elasticsearch bin/elasticsearch-service-tokens create elastic/kibana kibana-token
# 自行备份生成的令牌，若丢失需要重新生成并更新Kibana配置
sudo docker-compose exec elasticsearch cat /usr/share/elasticsearch/config/service_tokens
```
- 修改环境变量文件文件
```
# 将SERVICE_TOKEN elastic/kibana/kibana-token = xxx的值复制到KIBANA_SERVICE_ACCOUNT_TOKEN变量中
kibana:
  environment:
    ELASTICSEARCH_HOSTS: http://elasticsearch:9200
    ELASTICSEARCH_SERVICEACCOUNTTOKEN: <your-token>
```

### 使用 kibana_system 用户（备选）

- 创建 kibana_system 用户
```
curl -X POST "localhost:9200/_security/user/kibana_system" -H "Content-Type: application/json" -u elastic:<your-elastic-password> -d'
{
  "password": "<new-password-for-kibana>",
  "roles": ["kibana_system"]
}'
```
- 更新 docker-compose.yml 文件
```
kibana:
  environment:
    ELASTICSEARCH_HOSTS: http://elasticsearch:9200
    ELASTICSEARCH_USERNAME: kibana_system
    ELASTICSEARCH_PASSWORD: <new-password-for-kibana>
```

## 参考链接
