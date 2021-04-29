import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:qiniu_sdk_base/src/storage/task/task.dart';

import '../../../../auth/auth.dart';
import '../put_response.dart';

// 直传任务
class PutBySingleTask extends RequestTask<PutResponse> {
  /// 上传文件
  final Uint8List input;

  /// 上传凭证
  final String token;

  /// 资源名
  /// 如果不传则后端自动生成
  final String? key;

  late UpTokenInfo _tokenInfo;

  PutBySingleTask({
    required this.input,
    required this.token,
    this.key,
    RequestTaskController? controller,
  }) : super(controller: controller);

  @override
  void preStart() {
    _tokenInfo = Auth.parseUpToken(token);
    super.preStart();
  }

  @override
  Future<PutResponse> createTask() async {
    final formData = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(input),
      'token': token,
      'key': key,
    });

    final host = await config.hostProvider.getUpHost(
      accessKey: _tokenInfo.accessKey,
      bucket: _tokenInfo.putPolicy.getBucket(),
    );

    final response = await client.post<Map<String, dynamic>>(
      host,
      data: formData,
      cancelToken: controller?.cancelToken,
    );

    // response.data 应该是 none-nullable 而不是 nullable，如果 dio 修复了可以去掉 !
    return PutResponse.fromJson(response.data!);
  }
}
