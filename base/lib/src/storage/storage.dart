import 'dart:io';

import 'config/config.dart';
import 'task/put_parts_task/put_parts_task.dart';
import 'task/put_task.dart';
import 'task/task_manager.dart';

export 'config/config.dart';

/// 客户端
class Storage {
  late final Config config;
  late final RequestTaskManager taskManager;

  Storage({Config? config}) {
    this.config = config ?? Config();
    taskManager = RequestTaskManager(config: this.config);
  }

  // 单文件上传
  PutTask putFile(
    File file,
    String token, {
    PutOptions? options,
  }) {
    final task = PutTask(
      file: file,
      token: token,
      key: options?.key,
    );

    return taskManager.addRequestTask(task) as PutTask;
  }

  // 分片上传
  PutPartsTask putFileParts(
    File file,
    String token, {
    PutPartsOptions? options,
  }) {
    final task = PutPartsTask(
      file: file,
      token: token,
      key: options?.key,
      partSize: options?.partSize ?? 4,
      maxPartsRequestNumber: options?.maxPartsRequestNumber ?? 5,
    );

    return taskManager.addRequestTask(task) as PutPartsTask;
  }
}

class PutOptions {
  // 资源名。如果不传则后端自动生成
  final String? key;

  PutOptions({this.key});
}

class PutPartsOptions {
  // 资源名。如果不传则后端自动生成
  final String? key;

  /// 切片大小，单位 MB
  ///
  /// 超出 [partSize] 的文件大小会把每片按照 [partSize] 的大小切片并上传
  /// 默认 4MB，最小不得小于 1MB，最大不得大于 1024 MB
  final int partSize;

  // 最大并发请求数，默认 5
  final int maxPartsRequestNumber;

  PutPartsOptions({
    this.key,
    this.partSize = 4,
    this.maxPartsRequestNumber = 5,
  }) {
    if (partSize < 1 || partSize > 1024) {
      throw RangeError.range(partSize, 1, 1024, 'partSize',
          'partSize must be greater than 1 and less than 1024');
    }
  }
}
