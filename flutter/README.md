# 七牛云存储 Flutter SDK [![qiniu_flutter_sdk](https://img.shields.io/pub/v/qiniu_flutter_sdk.svg?label=qiniu_flutter_sdk)](https://pub.dev/packages/qiniu_flutter_sdk)

七牛云存储的 Flutter SDK。
基于七牛云 API 实现，封装了七牛云存储系统的的客户端操作。

## 快速导航

* [概述](#概述)
* [示例](#示例)
* [快速开始](#快速开始)
* [功能简介](#功能简介)
* [贡献代码](#贡献代码)
* [许可证](#许可证)

## 概述

Qiniu-Flutter-SDK 基于七牛云存储官方 [API](https://developer.qiniu.com/kodo) 构建，提供抽象的接口用于快速使用七牛的对象存储功能。

Qiniu-Flutter-SDK 为客户端 SDK，没有包含 `token` 生成实现，为了安全，`token` 建议通过网络从服务端获取，具体生成代码可以参考官方[文档](https://developer.qiniu.com/kodo/manual/1208/upload-token)，我们的很多服务端 SDK 已经实现了生成 Token 的功能，推荐直接使用，[查看其他 SDK](https://developer.qiniu.com/sdk#official-sdk)

## 示例

请查看 [Example](https://github.com/qiniu/dart-sdk/tree/master/flutter/example)

## 快速开始

编辑你的 `pubspec.yaml` 文件，在 `dependencies` 添加  `qiniu-flutter-sdk`，如下：

```yaml
dependencies:
  ...
  qiniu_flutter_sdk: // 这里输入你需要的版本
```

在你需要使用的地方 `import`，如下：

```dart
import 'package:qiniu_flutter_sdk/qiniu_flutter_sdk.dart';
```

### 快速使用

```dart
  // 创建 storage 对象
  storage = Storage();
  // 使用 storage 的 putFile 对象进行文件上传
  storage.putFile(File('./file.txt'), 'TOKEN')
    ..then(/* 上传成功 */)
    ..catchError(/* 上传失败 */);
```

### 监听进度/状态

```dart
  // 创建 storage 对象
  storage = Storage();

  // 创建 Controller 对象
  putController = PutController();

  // 添加整体进度监听
  putController.addProgressListener((double percent) {
    print('任务进度变化：已发送：$percent');
  });

  // 添加发送进度监听
  putController.addSendProgressListener((double percent) {
    print('已上传进度变化：已发送：$percent');
  });

  // 添加状态监听
  putController.addStatusListener((StorageStatus status) {
    print('状态变化: 当前任务状态：$status');
  });

  // 使用 storage 的 putFile 对象进行文件上传
  storage.putFile(File('./file.txt'), 'TOKEN', options: PutOptions(
    controller: putController,
  ))
```

### 取消正在上传的任务

```dart
  // 创建 storage 对象
  storage = Storage();

  // 创建 Controller 对象
  putController = PutController();

  // 使用 storage 的 putFile 对象进行文件上传
  storage.putFile(File('./file.txt'), 'TOKEN', options: PutOptions(
      controller: putController,
  ))

  // 取消当前任务
  putController.cancel()
```

## API 说明

### `storage`
  
使用前必须创建一个 `Storage`  实例

```dart
  // 创建 storage 对象
  storage = Storage();
```

同时，在构造 `Storage` 时可以传入一个 `Config` 控制内部的一些行为，如下：

```dart
  // 创建 storage 对象
  storage = Storage(config: Config(
    // 通过自己的 hostProvider 来使用自己的 host 进行上传
    hostProvider: HostProvider,
    // 可以通过实现 cacheProvider 来自己实现缓存系统支持分片断点续传
    cacheProvider: CacheProvider,
    // 如果你需要对网络请求进行更基础的一些操作，你可以实现自己的 HttpClientAdapter 处理相关行为
    httpClientAdapter: HttpClientAdapter,
    // 设定网络请求重试次数
    retryLimit: 3,
  ));
```

#### `HostProvider`

该接口是一个抽象的接口，大多数开发者不需要自己实现这个，除非你使用的是七牛的专/私有云服务，则可以通过实现自己的 `HostProvider` 来向自己的服务进行上传。

#### `CacheProvider`

该接口同样是一个抽象的接口，`SDK` 支持分片断点续传功能，断点续传的信息通过 `CacheProvider` 提供的能力进行存储，如果你需要更好的体验，可以自己实现这个接口来对信息进行持久化的存储。

#### `HttpClientAdapter`

该接口也是一个抽象的接口，如果你需要对网络请求进行进一步的自定义处理时，你可以通过实现一个 `HttpClientAdapter` 来接管 `SDK` 的所有请求。

#### `retryLimit`

 用于限制内部重试逻辑的重试次数， 当发生一些可重试级别的错误时，`SDK` 会使用 `retryLimit` 的次数约束自动进行尝试。

#### `PutController`

这里是一个重要的内容，对于整个上传任务的一些交互被封装到了这里，
`PutController` 用于对上传任务添加进度、状态的监听，同时可以通过 `PutController.cancel()` 对正在上传的任务进行取消。使用方式可以参考：[`监听进度/状态`](#监听进度状态)

- `addProgressListener` - 添加整体进度监听
- `addSendProgressListener` - 添加发送进度监听
- `addStatusListener` - 添加状态监听
- `cancel` - 取消当前任务

#### `PutOptions`

上传选项，可配置以下参数：

| 参数 | 说明 | 默认值 |
| --- | --- | --- |
| `key` | 资源名，不传则后端自动生成 | `null` |
| `mimeType` | 资源的 MIME 类型 | `null` |
| `forceBySingle` | 强制使用单文件上传，不使用分片 | `false` |
| `partSize` | 分片大小，单位 MB | `4` |
| `maxPartsRequestNumber` | 并发上传队列长度 | `3` |
| `customVars` | 自定义变量，key 必须以 `x:` 开始 | `null` |
| `controller` | 控制器，用于监听进度/状态/取消 | `null` |
| `accelerateUploading` | 上传加速 | `false` |

#### `StorageErrorType`

上传过程中可能出现的错误类型：

- `UNKNOWN` - 未知错误
- `IN_PROGRESS` - 相同任务正在执行中
- `NO_AVAILABLE_HOST` - 没有可用的上传域名
- `NO_AVAILABLE_REGION` - 没有可用的区域
- `CONNECT_TIMEOUT` - 连接超时
- `SEND_TIMEOUT` - 发送数据超时
- `RECEIVE_TIMEOUT` - 响应数据超时
- `CANCEL` - 请求取消
- `RESPONSE` - 服务端响应错误
- `RESOURCE_READ_EXCEPTION` - 资源读取异常

#### `Storage.putFile`

该接口内部封装了分片和直传两种实现，会根据文件的尺寸和上传配置信息自动选择使用分片还是直传的方式来上传对象

### 其他说明

1. 如果您想了解更多七牛的上传策略，建议您仔细阅读 [七牛官方文档-上传](https://developer.qiniu.com/kodo/manual/upload-types)。另外，七牛的上传策略是在后端服务指定的.
2. 如果Flutter SDK版本低于 3.0.0，需要override flutter_lints版本
```yaml
dependency_overrides: 
  flutter_lints: ^1.0.0
```

## 功能列表

* 单文件上传
* 分片上传
* 任务状态
* 任务进度
* 上传进度
* 失败重试

## 贡献代码

1. 登录 https://github.com

2. Fork git@github.com:qiniu/dart-sdk.git

3. 创建您的特性分支 (git checkout -b new-feature)

4. 提交您的改动 (git commit -am 'Added some features or fixed a bug')

5. 将您的改动记录提交到远程 git 仓库 (git push origin new-feature)

6. 然后到 github 网站的该 git 远程仓库的 new-feature 分支下发起 Pull Request

## 许可证

基于 Apache 2.0 协议发布
> Copyright (c) 2020 qiniu.com
