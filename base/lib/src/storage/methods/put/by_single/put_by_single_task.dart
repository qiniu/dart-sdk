import 'package:dio/dio.dart';

import '../../../../util/chunk_list.dart' show chunkList;
import '../../../../../qiniu_sdk_base.dart';
import '../../../resource/resource.dart';
import '../../../task/request_task.dart';

// 直传任务
class PutBySingleTask extends RequestTask<PutResponse> {
  final Resource resource;
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
    required Config config,
    required this.resource,
    required this.token,
    required this.options,
    required this.filename,
  }) : super(config, controller: options.controller);

  @override
  String taskID() {
    return resource.id;
  }

  @override
  Future<void> preStart() async {
    _tokenInfo = Auth.parseUpToken(token);
    // 顶层任务：重置进度基线，避免复用同一 Controller 发起第二次上传时
    // 进度被 `percent <= _lastNotified...` 过滤掉。retry 路径（preRestart）
    // 不调用，保持进度单调性。
    controller?.resetProgressBaseline();
    await super.preStart();
  }

  @override
  Future<void> postReceive(data) async {
    await resource.close();
    await super.postReceive(data);
  }

  @override
  Future<void> postError(error, {bool complete = false}) async {
    await resource.close();
    await super.postError(error, complete: complete);
  }

  @override
  Future<void> preRestart() async {
    await resource.close();
    await super.preRestart();
  }

  @override
  Future<PutResponse> createTask() async {
    await resource.open();

    final multipartFile = MultipartFile.fromStream(
      () {
        return resource
            .getStream()
            .expand((data) => chunkList(data, 64 * 1024));
      },
      resource.length,
      // 与其他 sdk 保持一致，没有 filename 就是问号
      filename: filename ?? '?',
    );

    final formDataMap = <String, dynamic>{
      'file': multipartFile,
      'token': token,
    };

    if (options.key != null) {
      formDataMap.addAll(<String, dynamic>{'key': options.key!});
    } else if (resource.name != null) {
      formDataMap.addAll(<String, dynamic>{'key': resource.name});
    }

    if (options.customVars != null) {
      formDataMap.addAll(options.customVars!);
    }

    final formData = FormData.fromMap(formDataMap);

    final host = await config.hostProvider.getUpHost(
      accessKey: _tokenInfo.accessKey,
      bucket: _tokenInfo.putPolicy.getBucket(),
      accelerateUploading: options.accelerateUploading,
      transregional: true,
    );

    final response = await client.post<Map<String, dynamic>>(
      host,
      data: formData,
      cancelToken: controller?.cancelToken,
    );
    checkResponse(response);

    return PutResponse.fromJson(response.data!);
  }
}
