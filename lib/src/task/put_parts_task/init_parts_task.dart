part of 'put_parts_task.dart';

/// initParts 的返回体
class InitParts {
  String uploadId;
  int expireAt;

  InitParts({this.uploadId, this.expireAt});

  factory InitParts.fromJson(Map json) {
    return InitParts(
      uploadId: json['uploadId'] as String,
      expireAt: json['expireAt'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'uploadId': uploadId, 'expireAt': expireAt};
  }
}

/// 初始化一个分片上传任务，为 [UploadPartsTask] 提供 uploadId
class InitPartsTask extends RequestTask<InitParts> with CacheMixin {
  String token;
  String bucket;
  String host;
  String key;
  File file;

  @override
  String _cacheKey;

  InitPartsTask({
    this.host,
    this.bucket,
    this.token,
    this.key,
    this.file,
  });

  static String getCacheKey(String path, String key, int length) {
    return 'qiniu_dart_sdk_init_parts_task_${path}_key_${key}_size_$length';
  }

  @override
  void preStart() {
    _cacheKey = InitPartsTask.getCacheKey(file.path, key, file.lengthSync());
    super.preStart();
  }

  @override
  Future<InitParts> createTask() async {
    final initParts = getCache();
    if (initParts != null) {
      return InitParts.fromJson(json.decode(initParts) as Map);
    }
    final response = await client.post<Map>(
      '$host/buckets/$bucket/objects/${base64Url.encode(utf8.encode(key))}/uploads',

      /// 这里 data 不传，dio 不会触发 cancel 事件
      data: {},
      options: Options(headers: {'Authorization': 'UpToken $token'}),
    );

    return InitParts.fromJson(response.data);
  }

  @override
  void postReceive(data) {
    setCache(json.encode(data.toJson()));
    super.postReceive(data);
  }
}
