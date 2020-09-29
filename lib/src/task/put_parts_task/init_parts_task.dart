part of 'put_parts_task.dart';

/// initParts 的返回体
class InitParts {
  String uploadId;
  int expireAt;

  InitParts({this.uploadId, this.expireAt});

  factory InitParts.fromJson(Map json) {
    return InitParts(
        uploadId: json['uploadId'] as String,
        expireAt: json['expireAt'] as int);
  }
}

/// 初始化一个分片上传任务，为 [UploadPartsTask] 提供 uploadId
class InitPartsTask extends AbstractRequestTask<InitParts> {
  String token;
  String bucket;
  String host;
  String key;

  InitPartsTask({
    this.host,
    this.bucket,
    this.token,
    this.key,
  });

  @override
  Future<InitParts> createTask() async {
    final initParts = config.cacheProvider.getItem('init_parts');
    if (initParts != null) {
      return InitParts.fromJson(json.decode(initParts) as Map);
    }
    final response = await client.post<Map>(
        '$host/buckets/$bucket/objects/${base64Url.encode(utf8.encode(key))}/uploads',

        /// data 不传，取消的话会有问题
        data: {},
        options: Options(
            headers: {'Content-Length': 0, 'Authorization': 'UpToken $token'}));

    return InitParts.fromJson(response.data);
  }
}
