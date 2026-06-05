import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:platform_info/platform_info.dart';
import 'package:qiniu_sdk_base/src/client/http_client_adapter.dart';
import 'package:qiniu_sdk_base/src/storage/storage.dart';
import 'package:qiniu_sdk_base/src/util/cache_provider_base.dart'
    as cache_provider;
import 'package:path/path.dart' show join;
import 'package:singleflight/singleflight.dart' as singleflight;

part 'cache.dart';
part 'host.dart';
part 'protocol.dart';
part 'region.dart';
part 'query.dart';

/// 客户端配置
///
/// [httpClientAdapter] 用于实际发起 HTTP 请求的适配器，未传时默认使用
/// [QiniuHttpClient]（带 30 秒读写闲时超时）。
/// 如果需要自定义网络层，推荐两种方式：
/// 1. 传入 `QiniuHttpClient(connectTimeout: ..., writeTimeout: ..., delegate: ...)`
///    覆盖部分参数；
/// 2. 直接实现 `package:dio/dio.dart` 的 [HttpClientAdapter] 接口，
///    注意此时不会享有 SDK 默认提供的闲时超时与背压保护。
class Config {
  final HostProvider hostProvider;
  final CacheProvider cacheProvider;
  final HttpClientAdapter httpClientAdapter;

  /// 单个域名请求失败的重试次数
  ///
  /// 各种网络请求失败的重试次数
  final int retryLimit;

  Config({
    HostProvider? hostProvider,
    CacheProvider? cacheProvider,
    HttpClientAdapter? httpClientAdapter,
    this.retryLimit = 2,
  })  : hostProvider = hostProvider ?? DefaultHostProviderV2(),
        cacheProvider = cacheProvider ?? DefaultCacheProvider(),
        httpClientAdapter = httpClientAdapter ?? QiniuHttpClient();

  /// 复制并替换部分字段，仅供 SDK 内部使用。
  ///
  /// `RequestTask.preStart` 中会基于用户传入的 [Config] 派生一个新的实例
  /// （注入内部 `_HostProvider` 包装），通过本方法可以避免漏拷贝字段。
  @internal
  Config copyWith({
    HostProvider? hostProvider,
    CacheProvider? cacheProvider,
    HttpClientAdapter? httpClientAdapter,
    int? retryLimit,
  }) {
    return Config(
      hostProvider: hostProvider ?? this.hostProvider,
      cacheProvider: cacheProvider ?? this.cacheProvider,
      httpClientAdapter: httpClientAdapter ?? this.httpClientAdapter,
      retryLimit: retryLimit ?? this.retryLimit,
    );
  }

  Future<String> get appUserAgent async => '';
}
