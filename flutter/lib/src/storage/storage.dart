import 'dart:io';
import 'dart:typed_data';

import 'package:qiniu_sdk_base/qiniu_sdk_base.dart' as qiniu_sdk_base;

export 'package:qiniu_sdk_base/qiniu_sdk_base.dart'
    show
        PutOptions,
        PutResponse,
        HostProvider,
        CacheProvider,
        HttpClientAdapter,
        QiniuError,
        StorageError,
        StorageErrorType,
        StorageStatus;

export './controller.dart';
export './config.dart' show Config;

import './config.dart';

/// Storage
class Storage {
  /// Storage
  Storage({Config? config})
      : _baseStorage = qiniu_sdk_base.Storage(config: config ?? Config());

  final qiniu_sdk_base.Storage _baseStorage;

  /// putFile
  Future<qiniu_sdk_base.PutResponse> putFile(
    File file,
    String token, {
    qiniu_sdk_base.PutOptions? options,
  }) {
    return _baseStorage.putFile(file, token, options: options);
  }

  /// putBytes
  Future<qiniu_sdk_base.PutResponse> putBytes(
    Uint8List bytes,
    String token, {
    qiniu_sdk_base.PutOptions? options,
  }) {
    return _baseStorage.putBytes(bytes, token, options: options);
  }
}
