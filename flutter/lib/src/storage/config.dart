import '../version.dart';

import 'package:qiniu_sdk_base/qiniu_sdk_base.dart' as qiniu_sdk_base;
import 'package:device_info_plus/device_info_plus.dart';

export 'package:qiniu_sdk_base/qiniu_sdk_base.dart'
    show HostProvider, CacheProvider, HttpClientAdapter;

import 'dart:io' show Platform;

class Config extends qiniu_sdk_base.Config {
  Config({
    super.hostProvider,
    super.cacheProvider,
    super.httpClientAdapter,
    super.retryLimit,
  });

  @override
  Future<String> get appUserAgent async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    final deviceInfo = await deviceInfoPlugin.deviceInfo;
    var userAgent = 'QiniuFlutter/v$currentVersion';

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

    return userAgent;
  }
}
