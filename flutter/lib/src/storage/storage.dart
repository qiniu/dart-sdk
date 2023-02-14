import 'dart:io';
import 'dart:typed_data';

import 'package:qiniu_sdk_base/qiniu_sdk_base.dart' as base;

export 'package:qiniu_sdk_base/qiniu_sdk_base.dart'
    show
        Config,
        PutOptions,
        PutResponse,
        HostProvider,
        CacheProvider,
        QiniuError,
        StorageError,
        StorageErrorType,
        StorageStatus;

export './controller.dart';

/// Storage
class Storage {
  /// Storage
  Storage({base.Config? config}) : _baseStorage = base.Storage(config: config);

  final base.Storage _baseStorage;

  /// putFile
  Future<base.PutResponse> putFile(
    File file,
    String token, {
    base.PutOptions? options,
  }) {
    return _baseStorage.putFile(file, token, options: options);
  }

  /// putBytes
  Future<base.PutResponse> putBytes(
    Uint8List bytes,
    String token, {
    base.PutOptions? options,
  }) {
    return _baseStorage.putBytes(bytes, token, options: options);
  }
}
