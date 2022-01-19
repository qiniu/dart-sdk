import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' show md5;
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

part 'bytes_resource.dart';
part 'file_resource.dart';
part 'stream_resource.dart';

// 抽象的资源概念，帮助统一内部的资源类型管理
abstract class Resource<T> {
  Resource({
    required this.rawResource,
    required int length,
    int? partSize,
  }) {
    _length = length;
    if (partSize != null) {
      chunkSize = partSize * 1024 * 1024;
    } else {
      chunkSize = length;
    }
  }
  // 能区分该资源的唯一 id
  String get id;
  late final T rawResource;
  late final int _length;
  int get length => _length;

  late final int chunkSize;
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
    // stream 支持分段读取，设置为 Broadcast stream 防止中断后无法继续监听
    stream = createStream().asBroadcastStream();
  }

  @override
  String toString() {
    return '';
  }
}

enum ResourceStatus { Init, Open, Close }
