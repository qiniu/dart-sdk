import '../put_controller.dart';

@Deprecated('use PutOptions')
class PutBySingleOptions {
  /// 资源名
  ///
  /// 如果不传则后端自动生成
  final String? key;

  /// 自定义变量，key 必须以 x: 开始
  final Map<String, String>? customVars;

  /// 控制器
  final PutController? controller;

  const PutBySingleOptions({this.key, this.customVars, this.controller});
}
