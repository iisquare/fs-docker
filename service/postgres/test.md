# test for postgres

### 测试数据

```sql
CREATE TABLE t (
    id serial PRIMARY KEY,
    dept int not null,
    age int not null,
    name varchar(30),
    create_time timestamp not null,
    last_login_time varchar(32)
);

comment on table t is '测试表';
comment on column t.id is '自增主键';
comment on column t.dept is '部门id';
comment on column t.age is '年龄';
comment on column t.name is '用户名称';
comment on column t.create_time is '注册时间';
comment on column t.last_login_time is '最后登录时间';

create index idx_t_dept on t(dept);
create index idx_t_create_time on t(create_time);
create index idx_t_last_login_time on t(last_login_time);

insert into t (dept, age, name, create_time, last_login_time) values(1, 25, 'user_1', '2018-01-01 00:00:00', '2018-03-01');

CREATE OR REPLACE PROCEDURE public.test_insert_procedure()
LANGUAGE plpgsql
AS $$
DECLARE
    i INT DEFAULT 1;
    counter INT DEFAULT 1;
BEGIN
    WHILE i < 29 LOOP
        INSERT INTO t(dept, age, name, create_time, last_login_time)
        SELECT 
            (random()*1000)::int as dept,
            FLOOR(20 + RANDOM() *(150 - 20 + 1)) as age,
            concat('user_', counter),
            create_time + (counter * (random()*100)::int * interval '1 second'),
            to_char(create_time + (counter * (random()*100)::int * interval '1 second') + 
                   ((random()*1000000)::int * interval '1 second'), 'YYYY-MM-DD')
        FROM t;
        -- 每次循环后都提交
        COMMIT;
        counter := counter + 1;
        i := i + 1;
    END LOOP;
END;
$$;

-- 调用存储过程
call public.test_insert_procedure();

```
