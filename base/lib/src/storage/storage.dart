import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' show basename;
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';

import 'methods/put/by_part/put_parts_task.dart';
import 'methods/put/by_single/put_by_single_task.dart';
import 'resource/resource.dart';
import 'task/request_task.dart';
import 'task/task_manager.dart';

export 'package:dio/dio.dart' show HttpClientAdapter;
export 'error/error.dart';
export 'methods/put/put.dart';
export 'status/status.dart';
export 'config/config.dart';

/// 客户端
class Storage {
  final Config config;

  /// 任务管理器，负责管理上传任务的执行
  final TaskManager _taskManager = TaskManager();

  Storage({Config? config}) : config = config ?? Config();

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
        config: config,
        resource: resource,
        options: options,
        token: token,
        filename: basename(file.path),
      );
    } else {
      task = PutByPartTask(
        config: config,
        token: token,
        options: options,
        resource: resource,
      );
    }

    if (_taskManager.hasTask(task.taskID())) {
      throw StorageError(
        type: StorageErrorType.IN_PROGRESS,
        message: '$resource is already in upload queue',
      );
    }

    unawaited(_taskManager.addTask(task));

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
        config: config,
        resource: resource,
        options: options,
        token: token,
        filename: null,
      );
    } else {
      task = PutByPartTask(
        config: config,
        token: token,
        options: options,
        resource: resource,
      );
    }

    if (_taskManager.hasTask(task.taskID())) {
      throw StorageError(
        type: StorageErrorType.IN_PROGRESS,
        message: '$resource is already in upload queue',
      );
    }

    unawaited(_taskManager.addTask(task));

    return task.future;
  }
}
