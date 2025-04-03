import 'package:flutter/foundation.dart';

import '../version.dart';

import 'package:qiniu_sdk_base/qiniu_sdk_base.dart' as qiniu_sdk_base;
import 'package:device_info_plus/device_info_plus.dart';

export 'package:qiniu_sdk_base/qiniu_sdk_base.dart'
    show HostProvider, CacheProvider, HttpClientAdapter;

import 'dart:io' show Platform;

/// 继承自base sdk的扩展配置类
class Config extends qiniu_sdk_base.Config {
  /// 继承自base sdk的扩展配置类
  Config({
    super.hostProvider,
    super.cacheProvider,
    super.httpClientAdapter,
    super.retryLimit,
  });

  @override
  Future<String> get appUserAgent async {
    var userAgent = 'QiniuFlutter/v$currentVersion';
    if (kIsWeb) {
      userAgent += ' (Web)';
    } else {
      final deviceInfoPlugin = DeviceInfoPlugin();
      final deviceInfo = await deviceInfoPlugin.deviceInfo;
      if (Platform.isAndroid) {
        userAgent += ' (Android ${deviceInfo.data['version']['release']})';
      } else if (Platform.isIOS) {
        userAgent +=
            ' (${deviceInfo.data['systemName']} ${deviceInfo.data['systemVersion']})';
      } else if (Platform.isLinux) {
        userAgent += ' (${deviceInfo.data['prettyName']})';
      } else if (Platform.isMacOS) {
        userAgent +=
            ' (${deviceInfo.data['hostName']} ${deviceInfo.data['osRelease']})';
      } else if (Platform.isWindows) {
        userAgent +=
            ' (${deviceInfo.data['productName']} ${deviceInfo.data['displayVersion']})';
      }
    }
    return userAgent;
  }
}
