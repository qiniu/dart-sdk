import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

part 'protocol.dart';
part 'host.dart';
part 'cache.dart';

class Config {
  final HostProvider hostProvider;
  final CacheProvider cacheProvider;
  final HttpClientAdapter httpClientAdapter;

  Config({
    HostProvider hostProvider,
    CacheProvider cacheProvider,
    HttpClientAdapter httpClientAdapter,
  })  : hostProvider = hostProvider ?? DefaultHostProvider(),
        cacheProvider = cacheProvider ?? DefaultCacheProvider(),
        httpClientAdapter = httpClientAdapter ?? DefaultHttpClientAdapter();
}
