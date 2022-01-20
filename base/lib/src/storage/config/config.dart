import 'package:dio/dio.dart';

import 'package:qiniu_sdk_base/src/storage/error/error.dart';

import 'http_adaptor/native_adaptor.dart'
    if (dart.library.html) 'http_adaptor/browser_adaptor.dart';

part 'cache.dart';
part 'host.dart';
part 'protocol.dart';

class Config {
  final HostProvider hostProvider;
  final CacheProvider cacheProvider;
  final HttpClientAdapter httpClientAdapter;

  /// 重试次数
  ///
  /// 各种网络请求失败的重试次数
  final int retryLimit;

  Config({
    HostProvider? hostProvider,
    CacheProvider? cacheProvider,
    HttpClientAdapter? httpClientAdapter,
    this.retryLimit = 3,
  })  : hostProvider = hostProvider ?? DefaultHostProvider(),
        cacheProvider = cacheProvider ?? DefaultCacheProvider(),
        httpClientAdapter = httpClientAdapter ?? createHttpAdaptor();
}
