import 'package:dio/dio.dart';

import '../../../../auth/auth.dart';
import '../../../resource/resource.dart';
import '../../../task/task.dart';
import '../put_response.dart';

// 直传任务
class PutBySingleTask extends RequestTask<PutResponse> {
  late final Resource _resource;

  /// 上传凭证
  final String token;

  /// 资源名
  /// 如果不传则后端自动生成
  final String? key;

  late UpTokenInfo _tokenInfo;

  PutBySingleTask({
    required dynamic resource,
    required this.token,
    this.key,
    RequestTaskController? controller,
  }) : super(controller: controller) {
    _resource = Resource.create(resource);
  }

  @override
  void preStart() {
    _tokenInfo = Auth.parseUpToken(token);
    super.preStart();
  }

  @override
  Future<PutResponse> createTask() async {
    final formData = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(_resource.readAsBytes()),
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

    return PutResponse.fromJson(response.data!);
  }
}
