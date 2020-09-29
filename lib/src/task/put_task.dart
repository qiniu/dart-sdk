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
    return Put(key: json['key'] as String, hash: json['hash'] as String);
  }
}

class PutTask extends AbstractRequestTask<Put> {
  /// 上传凭证
  String token;

  // 资源名。如果不传则后端自动生成
  String key;

  Protocol putprotocol;

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
  Future<Put> createTask() async {
    final _token = token ?? config?.token;
    final formData = FormData.fromMap({
      'token': _token,
      'key': key,
      'file': await MultipartFile.fromFile(file.path)
    });
    final host = region != null
        ? config.hostProvider.getHostByRegion(region)
        : await config.hostProvider.getHostByToken(_token, putprotocol);
    final response = await client.post<Map>(host, data: formData);

    return Put.fromJson(response.data);
  }
}
