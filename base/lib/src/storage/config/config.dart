import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:platform_info/platform_info.dart';
import 'package:qiniu_sdk_base/src/storage/storage.dart';
import 'package:qiniu_sdk_base/src/util/cache_provider_base.dart'
    as cache_provider;
import 'package:qiniu_sdk_base/src/util/random.dart';
import 'package:singleflight/singleflight.dart' as singleflight;
import 'package:path/path.dart' show join;

part 'cache.dart';
part 'host.dart';
part 'protocol.dart';
part 'region.dart';
part 'query.dart';

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
    this.retryLimit = 10,
  })  : hostProvider = hostProvider ?? DefaultHostProviderV2(),
        cacheProvider = cacheProvider ?? DefaultCacheProvider(),
        httpClientAdapter = httpClientAdapter ?? HttpClientAdapter();

  Future<String> get appUserAgent async => '';
}
