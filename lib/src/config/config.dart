import 'package:dio/dio.dart';
import 'package:qiniu_sdk_base/src/auth/auth.dart';

part 'protocol.dart';
part 'region.dart';
part 'cache.dart';

class Config {
  AbstractHostProvider hostProvider;
  AbstractCacheProvider cacheProvider;
  String token;

  Config({
    this.hostProvider,
    this.cacheProvider,
    this.token,
  });
}
