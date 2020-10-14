import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:qiniu_sdk_base/src/auth/auth.dart';

part 'protocol.dart';
part 'host.dart';
part 'cache.dart';

class Config {
  HostProvider hostProvider;
  CacheProvider cacheProvider;
  HttpClientAdapter httpClientAdapter;

  Config({
    this.hostProvider,
    this.cacheProvider,
    this.httpClientAdapter,
  }) {
    hostProvider = hostProvider ?? DefaultHostProvider();
    cacheProvider = cacheProvider ?? DefaultCacheProvider();
    httpClientAdapter = httpClientAdapter ?? DefaultHttpClientAdapter();
  }
}
