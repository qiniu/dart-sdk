part of 'put_parts_task.dart';

/// 创建文件，把切片信息合成为一个文件
class CompletePartsTask extends RequestTask<PutResponse> {
  final String token;
  final String bucket;
  final String uploadId;
  final List<Part> parts;
  final String host;
  final String key;

  CompletePartsTask({
    @required this.token,
    @required this.bucket,
    @required this.uploadId,
    @required this.parts,
    @required this.host,
    this.key,
    RequestTaskController controller,
  }) : super(controller: controller);

  @override
  Future<PutResponse> createTask() async {
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
