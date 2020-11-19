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
  final base.Storage _baseStorage;
  Storage({base.Config config}) : _baseStorage = base.Storage(config: config);

  Future<base.PutResponse> putFile(
    File file,
    String token, {
    base.PutOptions options,
  }) {
    return _baseStorage.putFile(file, token, options: options);
  }

  /// 单文件上传
  Future<base.PutResponse> putFileBySingle(
    File file,
    String token, {
    base.PutBySingleOptions options,
  }) {
    return _baseStorage.putFileBySingle(file, token, options: options);
  }

  /// 分片上传
  Future<base.PutResponse> putFileByPart(
    File file,
    String token, {
    base.PutByPartOptions options,
  }) {
    return _baseStorage.putFileByPart(file, token, options: options);
  }
}
