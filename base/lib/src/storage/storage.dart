import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' show basename;

import 'config/config.dart';
import 'methods/put/by_part/put_parts_task.dart';
import 'methods/put/by_single/put_by_single_task.dart';
import 'methods/put/put.dart';
import 'resource/resource.dart';
import 'task/task.dart';

export 'package:dio/dio.dart' show HttpClientAdapter;
export 'error/error.dart';
export 'methods/put/put.dart';
export 'status/status.dart';
export 'task/request_task.dart';
export 'task/task.dart';
export 'config/config.dart';

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
      name: options.key,
      partSize: useSingle ? null : options.partSize,
    );

    if (useSingle) {
      task = PutBySingleTask(
        resource: resource,
        options: options,
        token: token,
        filename: basename(file.path),
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
      name: options.key,
      partSize: useSingle ? null : options.partSize,
    );

    if (useSingle) {
      task = PutBySingleTask(
        resource: resource,
        options: options,
        token: token,
        filename: null,
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
