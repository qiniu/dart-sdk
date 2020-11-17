import 'dart:io';

import 'package:qiniu_sdk_base/qiniu_sdk_base.dart' as base;

export 'package:qiniu_sdk_base/qiniu_sdk_base.dart'
    show
        Config,
        PutOptions,
        PutResponse,
        HostProvider,
        CacheProvider,
        PutByPartOptions,
        RequestTaskStatus,
        PutBySingleOptions;

export './controller.dart';

class Storage {
  base.Storage baseStorage;
  Storage({base.Config config}) : baseStorage = base.Storage(config: config);

  Future<base.PutResponse> putFile(
    File file,
    String token, {
    base.PutOptions options,
  }) {
    return baseStorage.putFile(file, token, options: options);
  }

  /// 单文件上传
  Future<base.PutResponse> putFileBySingle(
    File file,
    String token, {
    base.PutBySingleOptions options,
  }) {
    return baseStorage.putFileBySingle(file, token, options: options);
  }

  /// 分片上传
  Future<base.PutResponse> putFileByPart(
    File file,
    String token, {
    base.PutByPartOptions options,
  }) {
    return baseStorage.putFileByPart(file, token, options: options);
  }
}
