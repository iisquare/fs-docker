# mongo

## 解决方案
- WARNING (Windows & OS X)，数据目录请勿挂载到共享目录下。

## 常用命令

### 集合

- 删除数据
```
db.collection.deleteOne(filter, options)
db.collection.deleteMany(filter, options)
db.myCollection.findOneAndDelete(
{ name: "Charlie" },
{ projection: { name: 1, age: 1 } }
);
```

## 参考
- [关于widows系统使用docker部署mongo时报错：Operation not permitted](https://blog.csdn.net/qq506930427/article/details/99658808)
