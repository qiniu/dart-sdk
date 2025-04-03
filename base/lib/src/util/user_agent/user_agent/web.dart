import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';

// 实际上，在Web平台上，浏览器可能会出于一些安全原因，禁止修改UA，具体表现为忽略这里的自定义UA
String getDefaultUserAgent() {
  final components = <String>['QiniuDart/v$currentVersion', 'Web'];
  return components.join(' ');
}
