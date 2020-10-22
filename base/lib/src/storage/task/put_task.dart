import 'dart:io';
import 'package:dio/dio.dart';
import 'request_task.dart';

// 直传请求响应
class Put {
  final String key;
  final String hash;

  Put({
    required this.key,
    required this.hash,
  });

  factory Put.fromJson(Map json) {
    return Put(
      key: json['key'] as String,
      hash: json['hash'] as String,
    );
  }
}

// 直传任务
class PutTask extends RequestTask<Put> {
  /// 上传文件
  final File file;

  /// 上传凭证
  final String token;

  /// 资源名 
  /// 如果不传则后端自动生成
  final String? key;

  PutTask({
    required this.file,
    required this.token,
    this.key,
  });

  @override
  Future<Put> createTask() async {
    final formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(file.path),
      'token': token,
      'key': key,
    });

    final host = await config.hostProvider.getUpHost(token: token);
    final response = await client.post<Map>(host, data: formData);

    return Put.fromJson(response.data);
  }
}
