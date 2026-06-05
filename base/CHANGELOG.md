## 0.8.0

### Breaking changes

- `Task` / `RequestTask` 生命周期方法签名由 `void` 改为 `Future<void>`
  （`preStart` / `postStart` / `postReceive` / `postError` / `preRestart` / `postRestart`）。
  外部继承 `RequestTask` 时所有重写方法必须改成 `async` / `Future<void>`。
- `storage.dart` 不再 export `RequestTask` / `Task` / `TaskManager`，
  这些类型回归内部实现。`HttpClientAdapter` 仍通过 `storage.dart` 透出，
  自定义网络适配器请直接实现 `dio` 的 `HttpClientAdapter` 或继承本 SDK 的 `QiniuHttpClient`。
- 删除已不再使用的 `RequestTaskManager`。

### New

- 新增 `QiniuHttpClient`：在 dio 默认 adapter 之上提供 `connectTimeout` /
  `writeTimeout` / `readTimeout`（请求/响应流闲时超时，pause-aware），
  并通过 `sendBufferSize`（默认 128KB）配合内核 SO_SNDBUF 触发写阶段背压检测。
- 新增 `QiniuIdleTimeoutException`：明确标识读/写阶段的闲时超时错误，
  上层 `StorageError.fromDioError` 据此精确映射到
  `SEND_TIMEOUT` / `RECEIVE_TIMEOUT`。
- `Config` 的默认 `httpClientAdapter` 改为 `QiniuHttpClient()`，
  即默认启用 30 秒读写闲时超时。如需关闭，传入
  `Config(httpClientAdapter: QiniuHttpClient(readTimeout: Duration.zero, writeTimeout: Duration.zero))`。
- 新增 `StorageErrorType.RESOURCE_READ_EXCEPTION` 错误类型，
  在资源读取异常（实际上传字节数与预期不符）时上报。

### Changed

- 分片上传进度改为基于字节权重计算，`RequestTaskController` 增加单调钳制
  屏蔽 retry 引起的进度回退。
- 分片上传断点续传恢复逻辑修复。
- 分片上传 retry 改为区域间重试：单分片失败后冻结当前区域 host，
  递增 regionIndex 切换下一区域。
- `HostProvider` 新增 `unfreezeOne()` 默认实现（空方法）。
  支持冻结的自定义实现仍需重写该方法以恢复正常工作。
- 修复 User-Agent 偶尔无效的问题。
- 调整 `Config.retryLimit` 默认值从 `10` 改为 `2`（单域名重试次数，
  多域名场景下总重试次数 = `retryLimit × 可用域名数`）。

## 0.7.5

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
