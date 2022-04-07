import 'package:dio/dio.dart';
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';

import '../../../resource/resource.dart';

// 直传任务
class PutBySingleTask extends RequestTask<PutResponse> {
  late Resource resource;

  final PutOptions options;

  /// 上传凭证
  final String token;

  // FormData Content-Disposition Header Field 里的 filename
  // 如果没有此字段且 multipart 超过 16m 后端会认为是非 file part，则报错
  // 这个同时也是魔法变量 fname 的值
  // TODO 补充测试
  final String? filename;

  late UpTokenInfo _tokenInfo;

  PutBySingleTask({
    required this.resource,
    required this.token,
    required this.options,
    required this.filename,
  }) : super(controller: options.controller);

  @override
  void preStart() {
    _tokenInfo = Auth.parseUpToken(token);
    super.preStart();
  }

  @override
  void postReceive(data) {
    super.postReceive(data);
    resource.close();
  }

  @override
  void postError(error) {
    super.postError(error);
    if (!isRetrying) {
      resource.close();
    }
  }

  @override
  Future<PutResponse> createTask() async {
    if (isRetrying) {
      // 单文件上传的重试需要从头开始传，所以先关了再开
      await resource.close();
    }
    await resource.open();

    final multipartFile = MultipartFile(
      resource.stream,
      resource.length,
      // 与其他 sdk 保持一致，没有 filename 就是问号
      filename: filename ?? '?',
    );

    final formDataMap = <String, dynamic>{
      'file': multipartFile,
      'token': token,
      'key': resource.name,
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
