import 'dart:io';

import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';

// 这个函数无论如何都不应该抛出异常，即使内部依赖的第三方库不支持目标运行平台
String getDefaultUserAgent() {
  final components = <String>[
    'QiniuDart/v$currentVersion', // SDK版本
    '(${Platform.operatingSystem}; ${Platform.operatingSystemVersion})', // OS 版本
    '(${Platform.version})', // Dart版本
  ];

  // 有的操作系统（如Windows）名称可能会返回中文，这里把所有非ascii字符都过滤掉，防止设置User-Agent时产生报错
  return String.fromCharCodes(
    components.join(' ').runes.where((r) => r <= 127),
  );
}
