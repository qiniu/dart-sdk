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
  final File file;
  final String token;
  final String bucket;
  final String host;
  final String? key;

  @override
  late final String _cacheKey;

  InitPartsTask({
    required this.file,
    required this.host,
    required this.bucket,
    required this.token,
    this.key,
  });

  static String getCacheKey(String path, int length, String? key) {
    return 'qiniu_dart_sdk_init_parts_task_${path}_key_${key}_size_$length';
  }

  @override
  void preStart() {
    super.preStart();
  }

  @override
  Future<InitParts> createTask() async {
    _cacheKey = InitPartsTask.getCacheKey(file.path, await file.length(), key);

    final headers = {'Authorization': 'UpToken $token'};
    final paramMap = <String, String>{'buckets': bucket};

    final initPartsCache = getCache();
    if (initPartsCache != null) {
      return InitParts.fromJson(json.decode(initPartsCache) as Map);
    }

    if (key != null) {
      paramMap.addAll({'objects': base64Url.encode(utf8.encode(key!))});
    }

    final response = await client.post<Map>(
      '$host/${paramMap.entries.join('/')}/uploads',

      /// 这里 data 不传，dio 不会触发 cancel 事件
      data: <String, dynamic>{},
      options: Options(headers: headers),
    );

    return InitParts.fromJson(response.data);
  }

  @override
  void postReceive(data) {
    setCache(json.encode(data.toJson()));
    super.postReceive(data);
  }
}
