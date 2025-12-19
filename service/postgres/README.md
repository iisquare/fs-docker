# PostgreSQL

暂留在17.x版本, 18+以上强制将PGDATA路径与版本关联/var/lib/postgresql/MAJOR/docker。
版本升级或数据迁移应该交由使用者自行运维。


### 存储空间

```sql
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size FROM pg_database;
SELECT relname, pg_size_pretty(pg_relation_size(relid)) AS size FROM pg_stat_user_tables;
```
