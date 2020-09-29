part of 'put_parts_task.dart';

/// completeParts 的返回体
class CompleteParts {
  /// 资源内容的 SHA1 值
  String hash;

  /// 上传到七牛云存储后资源名称
  String key;

  CompleteParts({this.hash, this.key});

  factory CompleteParts.fromJson(Map json) {
    return CompleteParts(
        hash: json['hash'] as String, key: json['key'] as String);
  }
}

/// 创建文件，把切片信息合成为一个文件
class CompletePartsTask extends AbstractRequestTask<CompleteParts> {
  String token;
  String host;
  String bucket;
  String key;
  String uploadId;
  List<Part> parts;

  CompletePartsTask({
    this.token,
    this.host,
    this.bucket,
    this.key,
    this.uploadId,
    this.parts,
  });

  @override
  Future<CompleteParts> createTask() async {
    final response = await client.post<Map>(
        '$host/buckets/$bucket/objects/${base64Url.encode(utf8.encode(key))}/uploads/$uploadId',
        data: {
          'parts': parts
            ..sort((a, b) => a.partNumber - b.partNumber)
            ..map((part) => part.toJson()).toList()
        },
        options: Options(headers: {'Authorization': 'UpToken $token'}));

    return CompleteParts.fromJson(response.data);
  }
}
