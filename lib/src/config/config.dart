import 'package:dio/dio.dart';
import 'package:qiniu_sdk_base/src/auth/auth.dart';

part 'protocol.dart';
part 'region.dart';
part 'cache.dart';

class Config {
  RegionProvider regionProvider;
  CacheProvider cacheProvider;
  String token;

  Config({
    this.regionProvider,
    this.cacheProvider,
    this.token,
  });
}
