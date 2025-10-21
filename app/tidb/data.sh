#!/bin/bash
for i in {0..9}
do
    mysql -h 127.0.0.1 -P 4000 -uroot -padmin888 -D fs_test -e "
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
    CROSS JOIN counter where id < 300000;
    "
    echo "Inserted batch $((i+1))/10"
done
