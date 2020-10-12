import 'dart:io';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import 'abstract_request_task.dart';

class Put {
  String key;
  String hash;

  Put({this.key, this.hash});

  factory Put.fromJson(Map json) {
    return Put(key: json['key'] as String, hash: json['hash'] as String);
  }
}

class PutTask extends RequestTask<Put> {
  /// 上传凭证
  String token;

  // 资源名。如果不传则后端自动生成
  String key;

  /// 上传文件
  File file;

  PutTask({
    @required this.token,
    @required this.file,
    this.key,
  })  : assert(token != null),
        assert(file != null);

  @override
  Future<Put> createTask() async {
    final formData = FormData.fromMap({
      'token': token,
      'key': key,
      'file': await MultipartFile.fromFile(file.path)
    });
    final host = await config.hostProvider.getUpHost(token: token);
    final response = await client.post<Map>(host, data: formData);

    return Put.fromJson(response.data);
  }
}
