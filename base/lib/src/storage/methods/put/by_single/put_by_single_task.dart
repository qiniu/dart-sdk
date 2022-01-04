import 'package:dio/dio.dart';
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';

import '../../../../auth/auth.dart';
import '../../../resource/resource.dart';
import '../../../task/task.dart';
import '../put_response.dart';

// 直传任务
class PutBySingleTask extends RequestTask<PutResponse> {
  late Resource resource;

  final dynamic rawResource;

  final int length;

  final PutOptions options;

  /// 上传凭证
  final String token;

  late UpTokenInfo _tokenInfo;

  PutBySingleTask({
    required this.rawResource,
    required this.length,
    required this.token,
    required this.options,
  }) : super(controller: options.controller);

  @override
  void preStart() {
    _tokenInfo = Auth.parseUpToken(token);
    resource = Resource.create(rawResource, length, partSize: length);
    super.preStart();
  }

  @override
  void postReceive(data) {
    resource.close();
    super.postReceive(data);
  }

  @override
  void postError(error) {
    // 有可能 resource 还没被打开就进入异常了，所以此时不需要 close
    if (resource.status == ResourceStatus.Open) {
      resource.close();
    }
    super.postError(error);
  }

  @override
  void preRestart() {
    resource = Resource.create(rawResource, length);
    super.preRestart();
  }

  @override
  Future<PutResponse> createTask() async {
    await resource.open();
    final multipartFile = MultipartFile(resource.stream, resource.length);

    final formDataMap = <String, dynamic>{
      'file': multipartFile,
      'token': token,
      'key': options.key,
    };

    if (options.customVars != null) {
      formDataMap.addAll(options.customVars!);
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
