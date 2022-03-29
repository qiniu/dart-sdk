import 'dart:io';
import 'dart:typed_data';

import 'package:qiniu_sdk_base/src/storage/resource/resource.dart';

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
    final resource = FileResource(
      file: file,
      length: await file.length(),
      partSize: options.partSize,
    );

    if (useSingle) {
      task = PutBySingleTask(
        resource: resource,
        options: options,
        token: token,
      );
    } else {
      task = PutByPartTask(
        token: token,
        options: options,
        resource: resource,
      );
    }

    taskManager.addTask(task);

    return task.future;
  }

  Future<PutResponse> putBytes(
    Uint8List bytes,
    String token, {
    PutOptions? options,
  }) async {
    options ??= PutOptions();
    RequestTask<PutResponse> task;
    final useSingle = options.forceBySingle == true ||
        bytes.length < (options.partSize * 1024 * 1024);
    final resource = BytesResource(
      bytes: bytes,
      length: bytes.length,
      partSize: options.partSize,
    );

    if (useSingle) {
      task = PutBySingleTask(
        resource: resource,
        options: options,
        token: token,
      );
    } else {
      task = PutByPartTask(
        token: token,
        options: options,
        resource: resource,
      );
    }

    taskManager.addTask(task);

    return task.future;
  }
}
