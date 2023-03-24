part of 'put_parts_task.dart';

/// 创建文件，把切片信息合成为一个文件
class CompletePartsTask extends RequestTask<PutResponse> {
  final String token;
  final String uploadId;
  final List<Part> parts;
  final String? key;

  late final UpTokenInfo _tokenInfo;

  /// 自定义变量，key 必须以 x: 开始
  final Map<String, String>? customVars;

  CompletePartsTask({
    required this.token,
    required this.uploadId,
    required this.parts,
    this.key,
    this.customVars,
    PutController? controller,
  }) : super(controller: controller);

  @override
  void preStart() {
    _tokenInfo = Auth.parseUpToken(token);
    super.preStart();
  }

  @override
  Future<PutResponse> createTask() async {
    final bucket = _tokenInfo.putPolicy.getBucket();

    final host = await config.hostProvider.getUpHost(
      bucket: bucket,
      accessKey: _tokenInfo.accessKey,
    );
    final headers = <String, dynamic>{'Authorization': 'UpToken $token'};
    final encodedKey = key != null ? base64Url.encode(utf8.encode(key!)) : '~';
    final paramUrl =
        '$host/buckets/$bucket/objects/$encodedKey/uploads/$uploadId';

    final data = <String, dynamic>{
      'parts': parts
        ..sort((a, b) => a.partNumber - b.partNumber)
        ..map((part) => part.toJson()).toList(),
    };

    if (customVars != null) {
      data['customVars'] = customVars;
    }

    final response = await client.post<Map<String, dynamic>>(
      paramUrl,
      data: data,
      options: Options(
        headers: headers,
      ),
    );

    return PutResponse.fromJson(response.data!);
  }
}
