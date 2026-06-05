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
    required this.id,
    required this.name,
    required this.length,
    int? partSize,
  }) : chunkSize = partSize != null ? partSize * 1024 * 1024 : length;

  /// 通过 [File] 创建一个 [FileResource]，会把文件的路径、大小等信息作为 id 的一部分，以区分不同的文件资源
  /// 在分片上传中，此 id 作为文件唯一性的判定依据，相同的文件会启动断点续传
  /// 表单不支持断点续传
  final String id;

  /// 资源名称，主要用于表单上传时作为文件名
  final String? name;

  /// 资源长度
  final int length;

  /// 资源分片大小，单位是字节
  final int chunkSize;

  ResourceStatus status = ResourceStatus.Init;

  /// 资源的字节流。
  ///
  /// 使用 broadcast + onListen 实现"分次拉取"的非标准协议：
  /// 调用方每次 `await for ... break` 都会从当前 offset 拿到下一个 chunk，
  /// 连续多次接力即可读完整资源（详见 `resource_test.dart`）。
  /// retry 时需要重新调 [open]，构造新的 stream 实例从头开始读。
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
