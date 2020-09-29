import 'dart:io';
import 'package:qiniu_sdk_base/src/task/put_parts_task/put_parts_task.dart';
import 'package:qiniu_sdk_base/src/task/task_manager.dart';

import 'config/config.dart';
import 'task/put_task.dart';

/// 客户端
class Storage {
  RequestTaskManager _taskManager;
  Config _config;

  Storage({
    String token,
    AbstractHostProvider hostProvider,
    AbstractCacheProvider cacheProvider,
  }) {
    _config = Config(
      token: token,
      cacheProvider: cacheProvider ?? CacheProvider(),
      hostProvider: hostProvider ?? HostProvider(),
    );
    _taskManager = RequestTaskManager(config: _config);
  }

  PutTask put(File file, {PutOptions options}) {
    final token = options?.token ?? _config.token;
    final key = options?.key;
    final region = options?.region;

    final task = PutTask(
      token: token,
      key: key,
      file: file,
      region: region,
      putprotocol: options?.putprotocol,
    );

    return _taskManager.addRequestTask(task) as PutTask;
  }

  // 分片上传
  PutPartsTask putParts(File file, {PutPartsOptions options}) {
    final token = options?.token ?? _config.token;
    final task = PutPartsTask(
      token: token,
      key: options?.key,
      file: file,
      partSize: options?.partSize,
      region: options?.region,
      maxPartsRequestNumber: options?.maxPartsRequestNumber,
      putprotocol: options?.putprotocol,
    );

    return _taskManager.addRequestTask(task) as PutPartsTask;
  }

  String get(String key) {
    throw UnimplementedError();
  }
}

class PutOptions {
  /// 上传凭证
  String token;

  // 资源名。如果不传则后端自动生成
  String key;

  /// 上传协议
  Protocol putprotocol;

  /// 上传区域
  ///
  /// 如果能提供此选项则无需发请求去后端根据 token 拿对应的区域
  dynamic region;

  PutOptions({this.token, this.key, this.region, this.putprotocol});
}

class PutPartsOptions {
  /// 上传凭证
  String token;

  // 资源名。如果不传则后端自动生成
  String key;

  /// 上传协议
  Protocol putprotocol;

  // 最大并发请求数，默认 5
  int maxPartsRequestNumber;

  /// 切片大小
  ///
  /// 超出 [partSize] 的文件大小会把每片按照 [partSize] 的大小切片并上传
  /// 默认 4MB，最小不得小于 1
  int partSize;

  /// 上传区域
  ///
  /// 如果能提供此选项则无需发请求去后端根据 token 拿对应的区域
  dynamic region;

  PutPartsOptions({
    this.token,
    this.key,
    this.partSize = 4,
    this.maxPartsRequestNumber = 5,
    this.region,
    this.putprotocol,
  }) {
    if (partSize < 1 || partSize > 1024) {
      throw RangeError.range(partSize, 1, 1024, 'partSize',
          'partSize must be greater than 1 and less than 1024');
    }
  }
}
