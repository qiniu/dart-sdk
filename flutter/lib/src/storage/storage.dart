import 'dart:io';
import 'dart:typed_data';

import 'package:qiniu_sdk_base_diox/qiniu_sdk_base_diox.dart' as base;

export 'package:qiniu_sdk_base_diox/qiniu_sdk_base_diox.dart'
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
        StorageStatus,
        PutBySingleOptions;

export './controller.dart';

class Storage {
  final base.Storage _baseStorage;
  Storage({base.Config? config}) : _baseStorage = base.Storage(config: config);

  Future<base.PutResponse> putFile(
    File file,
    String token, {
    base.PutOptions? options,
  }) {
    return _baseStorage.putFile(file, token, options: options);
  }

  Future<base.PutResponse> putBytes(
    Uint8List bytes,
    String token, {
    base.PutOptions? options,
  }) {
    return _baseStorage.putBytes(bytes, token, options: options);
  }
}
