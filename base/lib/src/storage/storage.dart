import 'dart:io';

import 'config/config.dart';
import 'task/put_parts_task/put_parts_task.dart';
import 'task/put_task.dart';
import 'task/task_manager.dart';

export 'config/config.dart';

/// 客户端
class Storage {
  RequestTaskManager taskManager;
  Config config;

  Storage({this.config}) {
    config = config ?? Config();
    taskManager = RequestTaskManager(config: config);
  }

  PutTask putFile(File file, String token, {PutOptions options}) {
    final key = options.key;

    final task = PutTask(
      token: token,
      key: key,
      file: file,
    );

    return taskManager.addRequestTask(task) as PutTask;
  }

  // 分片上传
  PutPartsTask putFileParts(
    File file,
    String token, {
    PutPartsOptions options,
  }) {
    final task = PutPartsTask(
      token: token,
      key: options.key,
      file: file,
      partSize: options.partSize,
      maxPartsRequestNumber: options.maxPartsRequestNumber,
    );

    return taskManager.addRequestTask(task) as PutPartsTask;
  }
}

class PutOptions {
  // 资源名。如果不传则后端自动生成
  String key;

  PutOptions({this.key});
}

class PutPartsOptions {
  // 资源名。如果不传则后端自动生成
  String key;

  // 最大并发请求数，默认 5
  int maxPartsRequestNumber;

  /// 切片大小，单位 MB
  ///
  /// 超出 [partSize] 的文件大小会把每片按照 [partSize] 的大小切片并上传
  /// 默认 4MB，最小不得小于 1MB，最大不得大于 1024 MB
  int partSize;

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
