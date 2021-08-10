import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' show md5;
import 'package:qiniu_sdk_base/src/storage/error/error.dart';

part 'file_resource.dart';
part 'bytes_resource.dart';

// 抽象的资源概念，帮助统一内部的资源类型管理
abstract class Resource {
  static Resource create(dynamic resource) {
    if (resource is File) {
      return FileResource(resource);
    }

    if (resource is Uint8List) {
      return BytesResource(resource);
    }

    throw StorageError(type: StorageErrorType.UNSUPPORTED_RESOURCE);
  }

  // 能区分该资源的唯一 id
  String get id;
  void open();
  void close();
  Uint8List read(int start, int end);
  Uint8List readAsBytes();
  int length();
}
