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

  /// 自定义变量，key 必须以 x: 开始
  final Map<String, String>? customVars;

  late UpTokenInfo _tokenInfo;

  PutBySingleTask({
    required dynamic resource,
    required this.token,
    this.key,
    this.customVars,
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
    final formDataMap = <String, dynamic>{
      'file': MultipartFile.fromBytes(_resource.readAsBytes()),
      'token': token,
      'key': key,
    };

    if (customVars != null) {
      formDataMap.addAll(customVars!);
    }

    final formData = FormData.fromMap(formDataMap);

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
