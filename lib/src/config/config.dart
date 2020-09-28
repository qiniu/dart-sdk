import 'package:dio/dio.dart';
import 'package:qiniu_sdk_base/src/auth/auth.dart';
import 'package:qiniu_sdk_base/src/task/task_manager.dart';

part 'protocol.dart';
part 'region.dart';
part 'cache.dart';

class Config {
  RegionProvider regionProvider;
  CacheProvider cacheProvider;
  String token;
  RequestTaskManager manager;
  dynamic region;
  Protocol protocol;

  Config({
    this.regionProvider,
    this.cacheProvider,
    this.token,
    this.region,
    this.protocol,
    this.manager,
  });
}
