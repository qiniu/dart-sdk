import '../put_controller.dart';

/// @deprecated
class PutByPartOptions {
  /// 资源名
  /// 如果不传则后端自动生成
  final String? key;

  /// 切片大小，单位 MB
  ///
  /// 超出 [partSize] 的文件大小会把每片按照 [partSize] 的大小切片并上传
  /// 默认 4MB，最小不得小于 1MB，最大不得大于 1024 MB
  final int partSize;

  final int maxPartsRequestNumber;

  /// 自定义变量，key 必须以 x: 开始
  final Map<String, String>? customVars;

  /// 控制器
  final PutController? controller;

  const PutByPartOptions({
    this.key,
    this.partSize = 4,
    this.maxPartsRequestNumber = 5,
    this.customVars,
    this.controller,
  });
}
