import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' show md5;
import 'package:meta/meta.dart';
import 'package:path/path.dart' show basename;

part 'bytes_resource.dart';
part 'file_resource.dart';

// TODO 等重试机制有调整，Resource 改成一次性的，重试需要重新创建 Resource
// 抽象的资源概念，帮助统一内部的资源类型管理
abstract class Resource {
  Resource({
    required this.name,
    required this.length,
    int? partSize,
  }) : chunkSize = partSize != null ? partSize * 1024 * 1024 : length;

  // 能区分该资源的唯一 id
  abstract final String id;
  final String? name;
  final int length;
  final int chunkSize;
  ResourceStatus status = ResourceStatus.Init;
  late Stream<List<int>> stream;
  Stream<List<int>> createStream();

  /// 清理 [Resource] 的方法
  ///
  /// 如果有清理的需求，可以在这里处理，比如 [RandomAccessFile.close]
  @mustCallSuper
  Future<void> close() async {
    status = ResourceStatus.Close;
  }

  /// 准备 [Resource.stream] 的方法。
  ///
  /// 可以针对特殊资源做初始化操作，比如 [File.open]
  @mustCallSuper
  Future<void> open() async {
    status = ResourceStatus.Open;
    stream = createStream();
  }

  Stream<List<int>> getStream() {
    return stream;
  }

  @override
  String toString() {
    return id;
  }
}

enum ResourceStatus { Init, Open, Close }
