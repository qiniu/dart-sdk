import 'package:meta/meta.dart';

class PutResponse {
  final String key;
  final String hash;

  /// 如果在上传策略自定义了 [returnBody]，
  /// 你可以读取并解析这个字段提取你自定义的响应信息
  final Map<String, dynamic> rawData;

  PutResponse({
    @required this.key,
    @required this.hash,
    @required this.rawData,
  });

  factory PutResponse.fromJson(Map<String, dynamic> json) {
    return PutResponse(
      key: json['key'] as String,
      hash: json['hash'] as String,
      rawData: json,
    );
  }
}
