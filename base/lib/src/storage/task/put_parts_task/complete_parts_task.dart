part of 'put_parts_task.dart';

/// completeParts 的返回体
class CompleteParts {
  /// 上传到七牛云存储后资源名称
  final String key;

  /// 资源内容的 SHA1 值
  final String hash;

  CompleteParts({
    required this.key,
    required this.hash,
  });

  factory CompleteParts.fromJson(Map<String, dynamic> json) {
    return CompleteParts(
      key: json['key'] as String,
      hash: json['hash'] as String,
    );
  }
}

/// 创建文件，把切片信息合成为一个文件
class CompletePartsTask extends RequestTask<CompleteParts> {
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
  Future<CompleteParts> createTask() async {
    final headers = <String, dynamic>{'Authorization': 'UpToken $token'};
    final paramMap = <String, String>{'buckets': bucket, 'uploads': uploadId};

    if (key != null) {
      paramMap.addAll({'objects': base64Url.encode(utf8.encode(key!))});
    }

    final response = await client.post<Map<String, dynamic>>(
      '$host/${paramMap.entries.join('/')}',
      data: {
        'parts': parts
          ..sort((a, b) => a.partNumber - b.partNumber)
          ..map((part) => part.toJson()).toList()
      },
      options: Options(headers: headers),
    );

    return CompleteParts.fromJson(response.data);
  }
}
