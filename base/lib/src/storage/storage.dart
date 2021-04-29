import 'dart:io';
import 'dart:typed_data';

import 'config/config.dart';
import 'methods/put/by_part/put_parts_task.dart';
import 'methods/put/by_single/put_by_single_task.dart';
import 'methods/put/put.dart';
import 'task/task.dart';

export 'package:dio/dio.dart' show HttpClientAdapter;
export 'config/config.dart';
export 'error/error.dart';
export 'methods/put/put.dart';
export 'status/status.dart';
export 'task/request_task.dart';
export 'task/task.dart';

/// 客户端
class Storage {
  late final Config config;
  late final RequestTaskManager taskManager;

  Storage({Config? config}) {
    this.config = config ?? Config();
    taskManager = RequestTaskManager(config: this.config);
  }

  Future<PutResponse> putFile(
    File file,
    String token, {
    PutOptions? options,
  }) async {
    options ??= PutOptions();
    RequestTask<PutResponse> task;
    final useSingle = options.forceBySingle == true ||
        file.lengthSync() < (options.partSize * 1024 * 1024);
    final fileBytes = await file.readAsBytes();

    if (useSingle) {
      task = PutBySingleTask(
        input: fileBytes,
        token: token,
        key: options.key,
        controller: options.controller,
      );
    } else {
      task = PutByPartTask(
        file: file,
        token: token,
        key: options.key,
        maxPartsRequestNumber: options.maxPartsRequestNumber,
        partSize: options.partSize,
        controller: options.controller,
      );
    }

    taskManager.addTask(task);

    return task.future;
  }

  /// 单文件上传
  Future<PutResponse> putFileBySingle(
    File file,
    String token, {
    PutBySingleOptions? options,
  }) async {
    options ??= PutBySingleOptions();
    final fileBytes = await file.readAsBytes();
    final task = PutBySingleTask(
      input: fileBytes,
      token: token,
      key: options.key,
      controller: options.controller,
    );

    taskManager.addTask(task);

    return task.future;
  }

  /// 分片上传
  Future<PutResponse> putFileByPart(
    File file,
    String token, {
    PutByPartOptions? options,
  }) {
    options ??= PutByPartOptions();
    final task = PutByPartTask(
      file: file,
      token: token,
      key: options.key,
      partSize: options.partSize,
      maxPartsRequestNumber: options.maxPartsRequestNumber,
      controller: options.controller,
    );

    taskManager.addTask(task);

    return task.future;
  }

  /// 上传 stream
  ///
  /// 该方法采用直传方式上传
  Future<PutResponse> putBytes(
    Uint8List bytes,
    String token, {
    PutBySingleOptions? options,
  }) async {
    options ??= PutBySingleOptions();

    final task = PutBySingleTask(
      input: bytes,
      token: token,
      key: options.key,
      controller: options.controller,
    );

    taskManager.addTask(task);

    return task.future;
  }
}
