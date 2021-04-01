class PutResponse {
  /// 文件名
  /// 
  /// 如果在上传策略自定义了 [returnBody]，这里会是空
  final String? key;

  /// 文件哈希
  /// 
  /// 如果在上传策略自定义了 [returnBody]，这里会是空
  final String? hash;

  /// 如果在上传策略自定义了 [returnBody]，
  /// 你可以读取并解析这个字段提取你自定义的响应信息
  final Map<String, dynamic>? rawData;

  PutResponse({
    this.key,
    this.hash,
    this.rawData,
  });

  factory PutResponse.fromJson(Map<String, dynamic> json) {
    return PutResponse(
      key: json['key'] as String?,
      hash: json['hash'] as String?,
      rawData: json,
    );
  }
}
