import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';
import 'dart:js' as js;

// 这个函数无论如何都不应该抛出异常，即使内部依赖的第三方库不支持目标运行平台
// 实际上，在Web平台上，浏览器可能会出于一些安全原因，禁止修改UA，具体表现为忽略这里的自定义UA
String getDefaultUserAgent() {
  final components = <String>['QiniuDart/v$currentVersion', 'Web'];

  try {
    final browserUserAgent = js.context['navigator']['userAgent']?.toString();
    if (browserUserAgent != null) components.add(browserUserAgent);
  } catch (e) {
    components.add('UnknownBrowserUA');
  }
  return components.join(' ');
}
