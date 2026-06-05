part of 'put_parts_task.dart';

/// initParts 的返回体
class InitParts {
  final int expireAt;
  final String uploadId;

  InitParts({
    required this.expireAt,
    required this.uploadId,
  });

  factory InitParts.fromJson(Map json) {
    return InitParts(
      uploadId: json['uploadId'] as String,
      expireAt: json['expireAt'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'uploadId': uploadId,
      'expireAt': expireAt,
    };
  }
}

/// 初始化一个分片上传任务，为 [UploadPartsTask] 提供 uploadId
class InitPartsTask extends RequestTask<InitParts> with CacheMixin<InitParts> {
  final Resource resource;
  final String token;
  final String? key;
  final bool accelerateUploading;
  final int regionIndex;

  @override
  late final String _cacheKey;
  late final UpTokenInfo _tokenInfo;

  InitPartsTask({
    required Config config,
    required this.resource,
    required this.token,
    this.key,
    PutController? controller,
    this.accelerateUploading = false,
    this.regionIndex = 0,
  }) : super(config, controller: controller);

  static String getCacheKey(int regionIndex, String resourceId, String? key) {
    final keyList = [
      'region/$regionIndex',
      'resource_id/$resourceId',
      'key/$key',
    ];
    return 'qiniu_dart_sdk_init_parts_task@@[${keyList.join("/")}]';
  }

  @override
  Future<void> preStart() async {
    _tokenInfo = Auth.parseUpToken(token);
    _cacheKey = InitPartsTask.getCacheKey(regionIndex, resource.id, key);
    await super.preStart();
  }

  @override
  Future<InitParts> createTask() async {
    final headers = {'Authorization': 'UpToken $token'};

    final initPartsCache = await getCache();
    if (initPartsCache != null) {
      return InitParts.fromJson(
        json.decode(initPartsCache) as Map<String, dynamic>,
      );
    }

    final bucket = _tokenInfo.putPolicy.getBucket();

    final host = await config.hostProvider.getUpHost(
      bucket: bucket,
      accessKey: _tokenInfo.accessKey,
      accelerateUploading: accelerateUploading,
      regionIndex: regionIndex,
    );

    final encodedKey = key != null ? base64Url.encode(utf8.encode(key!)) : '~';
    final paramUrl = '$host/buckets/$bucket/objects/$encodedKey/uploads';

    final response = await client.post<Map<String, dynamic>>(
      paramUrl,

      /// 这里 data 不传，dio 不会触发 cancel 事件
      data: <String, dynamic>{},
      options: Options(
        headers: headers,
        contentType: Headers.textPlainContentType,
      ),
    );
    checkResponse(response);

    return InitParts.fromJson(response.data!);
  }

  @override
  Future<void> postReceive(data) async {
    // 有效期往前推 3 小时，避免在上传过程中缓存过期导致的 uploadId 无效问题
    final expireAt = (data.expireAt - 3 * 3600) * 1000;
    if (expireAt > DateTime.now().millisecondsSinceEpoch) {
      // 缓存写入失败不应阻止正常上传流程，静默忽略。
      // uploadId 已成功拿到，缓存只是断点续传的优化手段。
      try {
        await setCache(
          json.encode(data.toJson()),
          expireAt: expireAt,
        );
      } catch (_) {}
    }
    await super.postReceive(data);
  }
}
