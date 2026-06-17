# redis

## 安装运行

### 增加密码认证

- 挂载配置文件
```
services:
  redis:
    volumes:
      - ./redis.conf:/usr/local/etc/redis/redis.conf:ro # 挂载配置文件
    command: redis-server /usr/local/etc/redis/redis.conf
# redis.conf
requirepass your_strong_password
```
- 直接在 command 中启动时传入密码
```
services:
  redis:
    command: redis-server --requirepass my_secret_password # 在这里设置你的密码
```
- 容器启动后设置密码
```
sudo docker-compose exec redis redis-cli
config get requirepass # 查看当前密码
config set requirepass "your_strong_password" # 设置新密码
config rewrite # 重写配置文件以保存更改
```

### 连接测试

```
sudo docker-compose exec redis redis-cli
auth your_strong_password # 输入你设置的密码
ping # 测试连接，应该返回 PONG
```

## 参考链接
