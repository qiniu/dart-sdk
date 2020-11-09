import 'dart:io';

import 'package:qiniu_sdk_base/qiniu_sdk_base.dart' as base;

export 'package:qiniu_sdk_base/qiniu_sdk_base.dart'
    show PutOptions, PutBySingleOptions, PutByPartOptions, RequestTaskStatus;

export './controller.dart';

class Storage {
  base.Storage baseStore;
  Storage({base.Config config}) : baseStore = base.Storage(config: config);

  Future<base.PutResponse> putFile(
    File file,
    String token, {
    base.PutOptions options,
  }) {
    return baseStore.putFile(file, token, options: options);
  }

  /// 单文件上传
  Future<base.PutResponse> putFileBySingle(
    File file,
    String token, {
    base.PutBySingleOptions options,
  }) {
    return baseStore.putFileBySingle(file, token, options: options);
  }

  /// 分片上传
  Future<base.PutResponse> putFileByPart(
    File file,
    String token, {
    base.PutByPartOptions options,
  }) {
    return baseStore.putFileByPart(file, token, options: options);
  }
}
