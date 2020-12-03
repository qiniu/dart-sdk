part of 'put_parts_task.dart';

/// 创建文件，把切片信息合成为一个文件
class CompletePartsTask extends RequestTask<PutResponse> {
  final String token;
  final String uploadId;
  final List<Part> parts;
  final String key;
  final VoidCallback onRestart;

  TokenInfo _tokenInfo;

  CompletePartsTask({
    @required this.token,
    @required this.uploadId,
    @required this.parts,
    @required this.onRestart,
    this.key,
    RequestTaskController controller,
  }) : super(controller: controller);

  @override
  void preStart() {
    _tokenInfo = Auth.parseUpToken(token);
    super.preStart();
  }

  @override
  void postRestart() {
    onRestart();
    super.postStart();
  }

  @override
  Future<PutResponse> createTask() async {
    final bucket = _tokenInfo.putPolicy.getBucket();

    final host = await config.hostProvider.getUpHost(
      bucket: bucket,
      accessKey: _tokenInfo.accessKey,
    );
    final headers = <String, dynamic>{'Authorization': 'UpToken $token'};
    final encodedKey = key != null ? base64Url.encode(utf8.encode(key)) : '~';
    final paramUrl =
        '$host/buckets/$bucket/objects/$encodedKey/uploads/$uploadId';

    final response = await client.post<Map<String, dynamic>>(
      paramUrl,
      data: {
        'parts': parts
          ..sort((a, b) => a.partNumber - b.partNumber)
          ..map((part) => part.toJson()).toList()
      },
      options: Options(headers: headers),
    );

    return PutResponse.fromJson(response.data);
  }
}
