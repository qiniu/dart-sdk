## 0.1.0

- Initial Release.

## 0.2.0

- 优化了 `StorageError` 输出的调用栈
- `CacheProvider` 的方法都改成异步的

## 0.2.1

- 修复关闭 App 缓存丢失的问题

## 0.2.2

- 增加 User-Agent(#39)

## 0.3.0

- 增加 null-safety(#43)

## 0.3.1

- 在 `PutOptions` 中增加 customVars 参数，为用户配置自定义变量提供入口
- 对 `PutResponse` 中 rawData 参数变更为 required