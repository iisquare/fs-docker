# test for tidb

### 测试数据

```sql
CREATE TABLE t (
    id int NOT NULL AUTO_INCREMENT PRIMARY KEY comment '自增主键',
    dept int not null comment '部门id',
    age int not null comment '年龄',
    name varchar(30) comment '用户名称',
    create_time datetime not null comment '注册时间',
    last_login_time varchar(32) comment '最后登录时间'
) comment '测试表';

create index idx_dept on t(dept);
create index idx_create_time on t(create_time);
create index idx_last_login_time on t(last_login_time);

insert into t values(1,1, 25, 'user_1', '2018-01-01 00:00:00', '2018-03-01');

INSERT INTO t(dept, age, name, create_time, last_login_time)
WITH RECURSIVE counter AS (
    SELECT 0 as v_i
    UNION ALL
    SELECT v_i + 1 FROM counter WHERE v_i < 29
)
SELECT 
    FLOOR(RAND() * 1000) as dept,
    FLOOR(20 + RAND() * (150 - 20 + 1)) as age,
    CONCAT('user_', counter.v_i + 1) as name,
    DATE_ADD(create_time, INTERVAL (counter.v_i * CAST(RAND() * 100 AS SIGNED)) SECOND) as create_time,
    DATE_FORMAT(DATE_ADD(DATE_ADD(create_time, INTERVAL (counter.v_i * CAST(RAND() * 100 AS SIGNED)) SECOND), 
                INTERVAL CAST(RAND() * 1000000 AS SIGNED) SECOND), '%Y-%m-%d') as last_login_time
FROM t
CROSS JOIN counter;

```
