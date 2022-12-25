## 0.4.1

- fix package file name

## 0.4.0

- 新增 putBytes 接口用于上传 Uint8List 类型的资源
- 去掉了手机 Platform 相关的 UA, 可能客户端收集更适合

## 0.3.3

- 修复 UserAgent 可能被设置为中文导致报错的问题

## 0.3.2

- 修复 `PutPolicy` 的 forceSaveKey 类型

## 0.3.1

- 在 `PutOptions` 中增加 customVars 参数，为用户配置自定义变量提供入口
- 对 `PutResponse` 中 rawData 参数变更为 required

## 0.3.0

- 增加 null-safety(#43)

## 0.2.2

- 增加 User-Agent(#39)

## 0.2.1

- 修复关闭 App 缓存丢失的问题

## 0.2.0

- 优化了 `StorageError` 输出的调用栈
- `CacheProvider` 的方法都改成异步的

## 0.1.0

- Initial Release.
