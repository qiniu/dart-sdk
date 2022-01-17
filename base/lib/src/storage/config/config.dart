import 'package:dio/adapter.dart';
import 'package:dio/adapter_browser.dart';
import 'package:dio/dio.dart';

import 'package:qiniu_sdk_base/src/storage/error/error.dart';

part 'cache.dart';
part 'host.dart';
part 'protocol.dart';
part 'platform.dart';

class Config {
  /// SDK 的运行平台, 默认 [Platform.IOS]
  final Platform platform;
  final HostProvider hostProvider;
  final CacheProvider cacheProvider;
  final HttpClientAdapter httpClientAdapter;

  /// 重试次数
  ///
  /// 各种网络请求失败的重试次数
  final int retryLimit;

  Config({
    this.platform = Platform.IOS,
    HostProvider? hostProvider,
    CacheProvider? cacheProvider,
    HttpClientAdapter? httpClientAdapter,
    this.retryLimit = 3,
  })  : hostProvider = hostProvider ?? DefaultHostProvider(),
        cacheProvider = cacheProvider ?? DefaultCacheProvider(),
        httpClientAdapter = httpClientAdapter ??
            // dio 的 adapter 需要手动指定
            (platform == Platform.Web
                ? BrowserHttpClientAdapter()
                : DefaultHttpClientAdapter());
}
