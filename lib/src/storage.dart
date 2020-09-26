import 'dart:io';
import 'package:qiniu_sdk_base/src/task/put_parts_task.dart';
import 'package:qiniu_sdk_base/src/task/task_manager.dart';

import 'config/config.dart';
import 'task/put_task.dart';

/// 客户端
class Storage {
  RequestTaskManager _taskManager;
  Config _config;

  Storage({
    String token,
    Protocol protocol,
    AbstractRegionProvider regionProvider,
    dynamic region,
  }) {
    _config = Config(
      token: token,
      protocol: protocol,
      region: region,
      regionProvider: regionProvider ?? RegionProvider(),
    );
    _taskManager = RequestTaskManager(config: _config);
  }

  PutTask<Put> put(File file, {PutOptions options}) {
    final token = options?.token ?? _config.token;
    final key = options?.key;
    final accept = options?.accept;
    final crc32 = options?.crc32;
    final region = options?.region;

    final task = PutTask(
      token: token,
      key: key,
      file: file,
      accept: accept,
      crc32: crc32,
      region: region,
    );

    return _taskManager.addRequestTask(task);
  }

  // 分片上传
  PutPartsTask putParts(File file, {PutPartsOptions options}) {
    final token = options?.token ?? _config.token;
    final task = PutPartsTask(
      token: token,
      key: options?.key,
      file: file,
      chunkSize: options?.chunkSize,
      region: options?.region,
      maxPartsRequestNumber: options?.maxPartsRequestNumber,
    );

    return _taskManager.addRequestTask(task);
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

  /// 超过 4m 自动开启分片上传
  int limit = 4 * 1024 * 1024;

  /// 上传内容的 crc32 校验码。如填入，则七牛服务器会使用此值进行内容检验。
  String crc32;

  /// 当 HTTP 请求指定 accept 头部时，七牛会返回 content-type 头部的值。该值用于兼容低版本 IE 浏览器行为。低版本 IE 浏览器在表单上传时，返回 application/json 表示下载，返回 text/plain 才会显示返回内容。
  String accept;

  /// 上传区域
  ///
  /// 如果能提供此选项则无需发请求去后端根据 token 拿对应的区域
  dynamic region;

  PutOptions(
      {this.token, this.key, this.crc32, this.limit, this.accept, this.region});
}

class PutPartsOptions {
  /// 上传凭证
  String token;

  // 资源名。如果不传则后端自动生成
  String key;

  // 最大请求数，默认 5
  int maxPartsRequestNumber;

  /// 切片大小
  ///
  /// 超出 [chunkSize] 的文件大小会把每片按照 [chunkSize] 的大小切片并上传
  /// 默认 4MB，最小不得小于 4
  int chunkSize;

  /// 上传区域
  ///
  /// 如果能提供此选项则无需发请求去后端根据 token 拿对应的区域
  dynamic region;

  /// 协议
  ///
  /// 可选的有 [Protocol.Http] 和 [Protocol.Https]
  Protocol protocol;

  PutPartsOptions(
      {this.token,
      this.key,
      this.chunkSize = 4,
      this.maxPartsRequestNumber = 5,
      this.region,
      this.protocol}) {
    if (chunkSize < 1 || chunkSize > 1024) {
      throw RangeError.range(chunkSize, 1, 1024, 'chunkSize',
          'chunkSize must be greater than 1 and less than 1024');
    }
  }
}

// enum PutStatus { Processing, Done, Canceled }

// typedef PutStatusListener = void Function(PutStatus status);

// mixin PutStatusListenersMixin {
//   final List<PutStatusListener> _statusListeners = [];

//   void addStatusListener(PutStatusListener listener) {
//     _statusListeners.add(listener);
//   }

//   void removeStatusListener(PutStatusListener listener) {
//     _statusListeners.remove(listener);
//   }

//   void notifyStatusListeners(PutStatus status) {
//     for (final listener in _statusListeners) {
//       listener(status);
//     }
//   }
// }

// /// Storage 的 put 方法返回的控制器
// class PutController<T> {
//   final AbstractRequestTask task;

//   PutController({this.task});

//   Future<T> toFuture() {
//     return task.toFuture();
//   }

//   listen(void Function(Response<T>) onSuccess) {
//     final unlistenReceiveListener = task.onReceive(onSuccess);

//     return () {
//       unlistenReceiveListener();
//     };
//   }
// }
