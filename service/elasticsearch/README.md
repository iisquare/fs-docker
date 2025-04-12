# elasticsearch

## 安装运行

### 文件权限
```
sudo chmod 777 /data/runtime/elasticsearch
```

## 最佳实践

### 最新最相关排序

- 评分脚本
```
POST /your_index/_search
{
    "query": {
        "script_score": {
            "query": { "match": { "content": "搜索词" } },
            "script": {
                "source": """
                Math.pow(sigmoid(doc.publichTime.value.toInstant().toEpochMilli() / 86400000, 1095, 0.8), ((20190 - doc.publichTime.value.toInstant().toEpochMilli() / 86400000)) / 30) * _score
                """
            }
        }
    }
}
其中：
"doc.publichTime.value.toInstant().toEpochMilli() / 86400000": 为发布日期距离1970年的天数。
"1095": 定义S型曲线的中心点（Midpoint）或阈值，即函数输出为0.5时的值为3年的天数。
"0.8": 控制曲线的陡峭度（Steepness）或斜率，即函数从低值到高值的过渡速度。
"20190": 为当前时间距离1970年的天数，需要调用端程序实时计算得出。
"30": 为时间衰减范围，即按照30天成指数级增长。
```

- 评分函数
```
POST /your_index/_search
{
    "query": {
        "function_score": {
            "query": { "match": { "content": "搜索词" } },
            "functions": [
                {
                    "linear": {
                        "publichTime": {
                            "origin": "now",
                            "scale": "30d",
                            "offset": "1d",
                            "decay": 0.5
                        }
                    }
                }
            ],
            "boost_mode": "sum"
        }
    }
}
参数说明：
origin: 基准时间（设为当前时间now）。
scale: 衰减跨度，超过此时间后得分显著下降（如30d表示30天）。
offset: 在此时间内无衰减（如1d表示1天内文档得分不降低）。
decay: 衰减率（0.5表示在origin + scale时的得分为基准的一半）。
```

### 结果去重

```
GET /your_index/_search
{
  "query": { "match": { "content": "搜索词" } },
  "collapse": {
    "field": "title.keyword",
    "inner_hits": {
      "name": "latest_best_match",
      "size": 1,
      "sort": [
        {"_score": "desc"},            // 保留最相关文档
        { "content_length": "desc" },  // 优先内容更长的文档
        { "pagerank": "desc" }         // 权威性维度
      ]
    }
  }
}
```

## 参考链接
