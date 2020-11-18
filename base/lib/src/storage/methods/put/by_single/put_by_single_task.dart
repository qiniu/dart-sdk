import 'dart:io';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import '../../../../auth/auth.dart';
import '../../../task/request_task.dart';
import '../put_response.dart';

// 直传任务
class PutBySingleTask extends RequestTask<PutResponse> {
  /// 上传文件
  final File file;

  /// 上传凭证
  final String token;

  /// 资源名
  /// 如果不传则后端自动生成
  final String key;

  PutBySingleTask({
    @required this.file,
    @required this.token,
    this.key,
    RequestTaskController controller,
  })  : assert(file != null),
        assert(token != null),
        super(controller: controller);

  @override
  Future<PutResponse> createTask() async {
    final tokenInfo = Auth.parseUpToken(token);
    final putPolicy = tokenInfo.putPolicy;

    final formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(file.path),
      'token': token,
      'key': key,
    });

    final host = await config.hostProvider.getUpHost(
      accessKey: tokenInfo.accessKey,
      bucket: putPolicy.getBucket(),
    );

    final response = await client.post<Map<String, dynamic>>(
      host,
      data: formData,
      cancelToken: controller?.cancelToken,
    );
    return PutResponse.fromJson(response.data);
  }
}
