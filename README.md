# Dart SDK

[![codecov](https://codecov.io/gh/qiniu/dart-sdk/branch/master/graph/badge.svg?token=5VOX6NJTKF)](https://codecov.io/gh/qiniu/dart-sdk)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![qiniu_sdk_base_diox](https://img.shields.io/pub/v/qiniu_sdk_base.svg?label=qiniu_sdk_base_diox)](https://pub.dev/packages/qiniu_sdk_base_diox)
[![qiniu_flutter_sdk_diox](https://img.shields.io/pub/v/qiniu_flutter_sdk.svg?label=qiniu_flutter_sdk_diox)](https://pub.dev/packages/qiniu_flutter_sdk_diox)

将 qiniu_sdk_base 和 qiniu_flutter_sdk 的 dio 依赖修改为 diox

## 目录说明

- base 封装了七牛各业务的基础实现
- flutter 该目录是 base + Flutter 的绑定实现，同时导出为单独的 package 提供给用户使用

### [Flutter SDK](https://github.com/qiniu/dart-sdk/tree/master/flutter)

七牛云业务基于 Dart 绑定 Flutter 的实现，为 Flutter 提供简易的使用方式，更多信息查看该目录下的 [README.md](https://github.com/qiniu/dart-sdk/tree/master/flutter/README.md) 文件。
