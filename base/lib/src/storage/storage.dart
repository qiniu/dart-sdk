import 'dart:io';

import 'config/config.dart';
import 'methods/put/by_part/put_parts_task.dart';
import 'methods/put/by_single/put_by_single_task.dart';
import 'methods/put/put.dart';
import 'methods/put/put_task.dart';
import 'task/task_manager.dart';

export 'config/config.dart';
export 'methods/put/put.dart';
export 'task/task.dart';

/// 客户端
class Storage {
  Config config;
  RequestTaskManager taskManager;

  Storage({Config config}) {
    this.config = config ?? Config();
    taskManager = RequestTaskManager(config: this.config);
  }

  PutController putFile(
    File file,
    String token, {
    PutOptions options,
  }) {
    final task = PutTask(
      file: file,
      token: token,
      forceBySingle: options?.forceBySingle ?? false,
      partSize: options?.partSize ?? 4,
      maxPartsRequestNumber: options?.maxPartsRequestNumber ?? 5,
      key: options?.key,
    );

    taskManager.addTask(task);
    return PutController(task);
  }

  /// 单文件上传
  PutController putFileBySingle(
    File file,
    String token, {
    PutBySingleOptions options,
  }) {
    final task = PutBySingleTask(
      file: file,
      token: token,
      key: options?.key,
    );

    taskManager.addTask(task);
    return PutController(task);
  }

  /// 分片上传
  /// FIXME: 应该使用 [listParts](https://developer.qiniu.com/kodo/api/6858/listparts) 重写现有缓存机制
  /// FIXME: 取消时应该实现 [abortMultipartUpload](https://developer.qiniu.com/kodo/api/6367/abort-multipart-upload) 接口
  PutController putFileByPart(
    File file,
    String token, {
    PutByPartOptions options,
  }) {
    final task = PutByPartTask(
      file: file,
      token: token,
      key: options?.key,
      partSize: options?.partSize ?? 4,
      maxPartsRequestNumber: options?.maxPartsRequestNumber ?? 5,
    );

    taskManager.addTask(task);
    return PutController(task);
  }
}
