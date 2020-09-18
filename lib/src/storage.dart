import 'dart:io';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import 'config.dart';

final http = Dio();

/// 客户端
class Storage {
  final String _token;
  final AbstractRegionProvider _regionProvider;
  final Protocol _upprotocol;

  Storage({token, regionProvider, upprotocol})
      : _regionProvider = RegionProvider(),
        _token = token,
        _upprotocol = upprotocol;

  Future<Put<Response<T>>> put<T>(File file, {PutOptions options}) async {
    final token = options?.token ?? _token;
    final formData = FormData.fromMap({
      'token': token,
      'key': options?.key,
      'file': await MultipartFile.fromFile(file.path)
    });

    final cancelToken = CancelToken();
    
    final host = await _regionProvider.getHostByToken(token, _upprotocol);
    // TODO 进度
    final task = http.post(host, data: formData, cancelToken: cancelToken);
    final put = Put<Response<T>>(cancelToken: cancelToken, task: task);

    return put;
  }

  // 分片上传
  pubParts() {}

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

  PutOptions({this.token, this.key, this.crc32, this.limit, this.accept});
}

class PutTask {}

enum PutStatus { Processing, Done, Canceled }

typedef PutStatusListener = void Function(PutStatus status);

mixin PutStatusListenersMixin {
  final List<PutStatusListener> _statusListeners = [];

  void addStatusListener(PutStatusListener listener) {
    _statusListeners.add(listener);
  }

  void removeStatusListener(PutStatusListener listener) {
    _statusListeners.remove(listener);
  }

  void notifyStatusListeners(PutStatus status) {
    for (final listener in _statusListeners) {
      listener(status);
    }
  }
}

/// Storage 的 put 方法返回的控制器
class Put<T> with PutStatusListenersMixin {
  final CancelToken _cancelToken;
  final Future<T> task;

  Put({this.task, cancelToken}) : _cancelToken = cancelToken;

  /// stop and clean cache
  void stop() {
    _cancelToken.cancel();
    notifyStatusListeners(PutStatus.Processing);
  }

  PutStatus _status = PutStatus.Processing;
}
