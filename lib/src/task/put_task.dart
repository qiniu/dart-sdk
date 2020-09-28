import 'dart:io';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import 'abstract_request_task.dart';

class Put {
  String key;
  String hash;

  Put({this.key, this.hash});

  factory Put.fromJson(Map json) {
    return Put(key: json['key'], hash: json['hash']);
  }
}

class PutTask<T extends Put> extends AbstractRequestTask<T> {
  /// 上传凭证
  String token;

  // 资源名。如果不传则后端自动生成
  String key;

  /// 上传内容的 crc32 校验码。如填入，则七牛服务器会使用此值进行内容检验。
  String crc32;

  /// 当 HTTP 请求指定 accept 头部时，七牛会返回 content-type 头部的值。该值用于兼容低版本 IE 浏览器行为。低版本 IE 浏览器在表单上传时，返回 application/json 表示下载，返回 text/plain 才会显示返回内容。
  String accept;

  /// 上传区域
  dynamic region;

  /// 上传文件
  File file;

  PutTask({
    @required this.token,
    @required this.file,
    this.accept,
    this.crc32,
    this.key,
    this.region,
  })  : assert(token != null),
        assert(file != null);

  @override
  Future<T> createTask() async {
    final formData = FormData.fromMap({
      'token': token ?? config?.token,
      'key': key,
      'file': await MultipartFile.fromFile(file.path)
    });
    final host = region != null
        ? config.regionProvider.getHostByRegion(region)
        : await config.regionProvider
            .getHostByToken(config.token, config.protocol);
    final response = await client.post(host, data: formData);

    return Put.fromJson(response.data);
  }
}
