import 'dart:io';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import 'task.dart';

class PutTask<T> extends AbstractRequestTask<T> {
  /// 上传凭证
  String token;

  // 资源名。如果不传则后端自动生成
  String key;

  /// 上传内容的 crc32 校验码。如填入，则七牛服务器会使用此值进行内容检验。
  String crc32;

  /// 当 HTTP 请求指定 accept 头部时，七牛会返回 content-type 头部的值。该值用于兼容低版本 IE 浏览器行为。低版本 IE 浏览器在表单上传时，返回 application/json 表示下载，返回 text/plain 才会显示返回内容。
  String accept;

  /// 上传文件
  File file;

  PutTask(
      {@required this.token,
      this.accept,
      this.crc32,
      @required this.file,
      this.key});

  @override
  void listenProgress(listener) {
    progressListeners.add(listener);
  }

  @override
  void unlistenProgress(listener) {
    progressListeners.remove(listener);
  }

  @override
  void notifyProgressListeners(int sent, int total) {
    for (final listener in progressListeners) {
      listener(sent, total);
    }
  }

  @override
  Future<Response<T>> createRequest() async {
    final formData = FormData.fromMap({
      'token': token ?? config?.token,
      'key': key,
      'file': await MultipartFile.fromFile(file.path)
    });
    final host = await config.regionProvider
        .getHostByToken(config.token, config.upprotocol);
    return client.post<T>(host,
        data: formData,
        cancelToken: cancelToken,
        onSendProgress: notifyProgressListeners);
  }
}
