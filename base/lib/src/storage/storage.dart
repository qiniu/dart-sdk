import 'dart:io';

import 'config/config.dart';
import 'controller.dart';
import 'task/put_by_single_task.dart';
import 'task/put_parts_task/put_parts_task.dart';
import 'task/put_response.dart';
import 'task/put_task.dart';
import 'task/task_manager.dart';

export './controller.dart';
export 'config/config.dart';

/// 客户端
class Storage {
  Config config;
  RequestTaskManager taskManager;

  Storage({Config config}) {
    this.config = config ?? Config();
    taskManager = RequestTaskManager(config: this.config);
  }

  PutController<PutResponse> putFile(
    File file,
    String token, {
    PutOptions options,
  }) {
    final task = PutTask(
      file: file,
      token: token,
      automaticSliceSize: options?.automaticSliceSize ?? 4,
      partSize: options?.partSize ?? 4,
      maxPartsRequestNumber: options?.maxPartsRequestNumber ?? 5,
      key: options?.key,
    );

    taskManager.addTask(task);
    return PutController(task);
  }

  /// 单文件上传
  PutController<PutResponse> putFileBySingle(
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
  PutController<PutResponse> putFileByPart(
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

class PutOptions {
  /// 资源名
  /// 如果不传则后端自动生成
  final String key;

  /// 自动启用分片上传的大小
  /// 当文件尺寸大于该设置时自动启用分片上传，否则使用但文件直传
  final int automaticSliceSize;

  /// 使用分片上传时的分片大小，默认值 4，单位为 MB
  final int partSize;

  /// 并发上传的队列长度，默认值为 5
  final int maxPartsRequestNumber;

  PutOptions({
    this.key,
    this.automaticSliceSize,
    this.partSize,
    this.maxPartsRequestNumber,
  });
}

class PutBySingleOptions {
  /// 资源名
  /// 如果不传则后端自动生成
  final String key;

  PutBySingleOptions({this.key});
}

class PutByPartOptions {
  /// 资源名
  /// 如果不传则后端自动生成
  final String key;

  /// 切片大小，单位 MB
  ///
  /// 超出 [partSize] 的文件大小会把每片按照 [partSize] 的大小切片并上传
  /// 默认 4MB，最小不得小于 1MB，最大不得大于 1024 MB
  final int partSize;

  final int maxPartsRequestNumber;

  PutByPartOptions({
    this.key,
    this.partSize,
    this.maxPartsRequestNumber,
  });
}
