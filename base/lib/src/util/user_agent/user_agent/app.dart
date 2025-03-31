import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';
import 'package:system_info2/system_info2.dart';
import 'package:platform_info/platform_info.dart';

// 这个函数无论如何都不应该抛出异常，即使内部依赖的第三方库不支持目标运行平台
String getDefaultUserAgent() {
  final components = <String>['QiniuDart/v$currentVersion'];

  try {
    platform.when(
      iOS: () {
        components.add('iOS');
      },
      orElse: () {
        // SystemInfo2 只支持android/linux/macos/windows
        components.addAll([
          '(${SysInfo.kernelName}; ${SysInfo.kernelVersion}; ${SysInfo.kernelArchitecture})',
          '(${SysInfo.operatingSystemName}; ${SysInfo.operatingSystemVersion})',
        ]);
      },
    );
  } catch (e) {
    // 其他任何报错
    components.add('UnknownPlatform');
  }

  // 有的操作系统（如Windows）名称可能会返回中文，这里把所有非ascii字符都过滤掉，防止设置User-Agent时产生报错
  return String.fromCharCodes(
    components.join(' ').runes.where((r) => r <= 127),
  );
}
