import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:qiniu_sdk_base/src/storage/storage.dart';

part 'cache.dart';
part 'host.dart';
part 'protocol.dart';
part 'region.dart';

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
        httpClientAdapter = httpClientAdapter ?? HttpClientAdapter();

  Future<String> get appUserAgent async => '';
}
