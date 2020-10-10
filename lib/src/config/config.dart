import 'package:dio/dio.dart';
import 'package:qiniu_sdk_base/src/auth/auth.dart';

part 'protocol.dart';
part 'host.dart';
part 'cache.dart';

class Config {
  HostProvider hostProvider;
  CacheProvider cacheProvider;

  Config({
    this.hostProvider,
    this.cacheProvider,
  }) {
    hostProvider = hostProvider ?? DefaultHostProvider();
    cacheProvider = cacheProvider ?? DefaultCacheProvider();
  }
}
