import 'dart:io';

import 'package:qiniu_sdk_base/qiniu_sdk_base.dart' as base;

export 'package:qiniu_sdk_base/qiniu_sdk_base.dart'
    show
        Config,
        PutOptions,
        PutResponse,
        HostProvider,
        CacheProvider,
        HttpClientAdapter,
        QiniuError,
        StorageError,
        StorageErrorType,
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
}
