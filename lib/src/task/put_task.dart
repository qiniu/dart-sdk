import 'dart:io';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:qiniu_sdk_base/src/config/config.dart';

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

  Protocol putprotocol;

  /// 上传内容的 crc32 校验码。如填入，则七牛服务器会使用此值进行内容检验。
  // TODO 实现这个
  String crc32;

  /// 上传区域
  dynamic region;

  /// 上传文件
  File file;

  PutTask({
    @required this.token,
    @required this.file,
    this.key,
    this.region,
    this.putprotocol = Protocol.Http,
  })  : assert(token != null),
        assert(file != null);

  @override
  Future<T> createTask() async {
    final _token = token ?? config?.token;
    final formData = FormData.fromMap({
      'token': _token,
      'key': key,
      'file': await MultipartFile.fromFile(file.path)
    });
    final host = region != null
        ? config.regionProvider.getHostByRegion(region)
        : await config.regionProvider.getHostByToken(_token, putprotocol);
    final response = await client.post(host, data: formData);

    return Put.fromJson(response.data);
  }
}
