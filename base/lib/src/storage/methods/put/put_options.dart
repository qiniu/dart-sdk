import 'put_controller.dart';

class PutOptions {
  /// 资源名
  ///
  /// 如果不传则后端自动生成
  final String? key;

  /// mimeType
  /// 
  /// 资源的 MIME 类型，如 image/jpeg
  final String? mimeType;

  /// 强制使用单文件上传，不使用分片，默认值 false
  ///
  /// 如果使用 putStream, 这个值会被忽略
  final bool forceBySingle;

  /// 使用分片上传时的分片大小，默认值 4，单位为 MB
  final int partSize;

  /// 并发上传的队列长度，默认值为 5
  final int maxPartsRequestNumber;

  /// 自定义变量，key 必须以 x: 开始
  final Map<String, String>? customVars;

  /// 控制器
  final PutController? controller;

  const PutOptions({
    this.key,
    this.mimeType,
    this.forceBySingle = false,
    this.partSize = 4,
    this.maxPartsRequestNumber = 5,
    this.customVars,
    this.controller,
  }) : assert(
          partSize >= 1 && partSize <= 1024,
          'partSize must be greater than or equal to 1 and less than or equal to 1024',
        );
}
