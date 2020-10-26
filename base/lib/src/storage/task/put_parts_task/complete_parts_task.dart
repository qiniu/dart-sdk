part of 'put_parts_task.dart';

/// 创建文件，把切片信息合成为一个文件
class CompletePartsTask extends RequestTask<PutResponse> {
  final String token;
  final String bucket;
  final String uploadId;
  final List<Part> parts;
  final String host;
  final String? key;

  CompletePartsTask({
    required this.token,
    required this.bucket,
    required this.uploadId,
    required this.parts,
    required this.host,
    this.key,
  });

  @override
  Future<PutResponse> createTask() async {
    final headers = <String, dynamic>{'Authorization': 'UpToken $token'};
    final paramMap = <String, String>{'buckets': bucket, 'uploads': uploadId};

    if (key != null) {
      paramMap.addAll({'objects': base64Url.encode(utf8.encode(key!))});
    }

    final paramString =
        paramMap.entries.map((e) => '${e.key}/${e.value}').join('/');

    final response = await client.post<Map<String, dynamic>>(
      '$host/$paramString',
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
