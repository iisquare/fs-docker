# PostgreSQL

### 存储空间

```sql
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size FROM pg_database;
SELECT relname, pg_size_pretty(pg_relation_size(relid)) AS size FROM pg_stat_user_tables;
```
