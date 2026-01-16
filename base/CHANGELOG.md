## 0.7.4

- 文件进行第一次上传时，如果域名全部冻结，会随机选择一个域名进行上传

## 0.7.3

- 优化表单上传进度更新粒度
- 修复分片上传重试时进度超过`100%`的问题

## 0.7.2

- 解除platform_info和system2的依赖，以修复Android平台小概率崩溃问题

## 0.7.1

- 修复由于 SystemInfo2 引入导致的 Web/iOS/Windows 平台的不兼容问题

## 0.7.0

- 增强区域查询和上传的可靠性

## 0.6.3

- 补充遗漏的 Content-Type

## 0.6.2

- 移除冗余的 uuid 依赖声明

## 0.6.1

- 修复分片上传中断恢复后文件内容出错的问题

## 0.6.0

- 更新 uuid 到最新版本，对 Flutter SDK 的最低版本要求提升到 3.0

## 0.5.2

- 添加上传时的 mimetype 支持（仅分片上传支持）

## 0.5.1

- 修复由于 dio 更新内部自动替换 null 为空字符串导致的 614 错误问题。

## 0.5.0

- upgrade dio to 5.0.0

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
