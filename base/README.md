# Qiniu Sdk Base [![qiniu_sdk_base](https://img.shields.io/pub/v/qiniu_sdk_base.svg?label=qiniu_sdk_base_diox)](https://pub.dev/packages/qiniu_sdk_base_diox) [![codecov](https://codecov.io/gh/qiniu/dart-sdk/branch/master/graph/badge.svg?token=5VOX6NJTKF)](https://codecov.io/gh/qiniu/dart-sdk)

七牛 dart 平台 sdk 的 base 包，为上层 sdk 提供基础设施和共享代码。

> 请不要在业务代码中使用此包。此包的定位为上层提供功能，不预期被使用的接口(可能为其他平台提供的接口)可能会随时被调整。

## 功能列表

* 单文件上传
* 分片上传
* 任务状态
* 任务进度
* 上传进度
* 失败重试

## 如何测试

创建 `.env` 文件，并输入如下内容

```
export QINIU_DART_SDK_ACCESS_KEY=
export QINIU_DART_SDK_SECRET_KEY=
export QINIU_DART_SDK_TOKEN_SCOPE=
```


在 `.env` 文件中填好敏感数据，即 ak、sk、scope

接着运行如下指令

`pub run test`
