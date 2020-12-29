import '../put_controller.dart';

class PutBySingleOptions {
  /// 资源名
  ///
  /// 如果不传则后端自动生成
  final String key;

  /// 控制器
  final PutController controller;

  const PutBySingleOptions({this.key, this.controller});
}
