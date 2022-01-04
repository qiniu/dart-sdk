import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' show md5;
import 'package:uuid/uuid.dart' show Uuid;
import 'package:meta/meta.dart';
import 'package:qiniu_sdk_base/src/storage/error/error.dart';

part 'file_resource.dart';
part 'bytes_resource.dart';
part 'stream_resource.dart';

var _uuid = Uuid();

// 抽象的资源概念，帮助统一内部的资源类型管理
abstract class Resource<T> {
  static Resource create(dynamic resource, int length, {int? partSize}) {
    if (resource is File) {
      return FileResource(resource, length, partSize: partSize);
    }

    if (resource is Uint8List) {
      return BytesResource(resource, length, partSize: partSize);
    }

    throw StorageError(type: StorageErrorType.UNSUPPORTED_RESOURCE);
  }

  Resource(this.resource, this.length, {int? partSize}) {
    if (partSize != null) {
      chunkSize = partSize * 1024 * 1024;
    } else {
      chunkSize = length;
    }
  }

  // 能区分该资源的唯一 id
  String get id => _uuid.v4();
  late final T resource;
  final int length;

  late final int chunkSize;
  ResourceStatus status = ResourceStatus.Init;
  late Stream<List<int>> stream;
  Stream<List<int>> createStream();

  @mustCallSuper
  Future<void> close() async {
    status = ResourceStatus.Close;
  }

  @mustCallSuper
  Future<void> open() async {
    status = ResourceStatus.Open;
    stream = createStream().asBroadcastStream();
  }
}

enum ResourceStatus { Init, Open, Close }
