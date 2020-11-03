import 'put_controller.dart';

class PutOptions {
  /// 资源名
  ///
  /// 如果不传则后端自动生成
  final String key;

  /// 强制使用直传，不使用分片
  final bool forceBySingle;

  /// 使用分片上传时的分片大小，默认值 4，单位为 MB
  final int partSize;

  /// 并发上传的队列长度，默认值为 5
  final int maxPartsRequestNumber;

  /// 控制器
  final PutController controller;

  PutOptions({
    this.key,
    this.forceBySingle,
    this.partSize,
    this.maxPartsRequestNumber,
    this.controller,
  });
}
