part of 'config.dart';

abstract class BucketRegionsQuery {
  Future<RegionsProvider> query({
    required String accessKey,
    required String bucketName,
    bool accelerateUploading = false,
  });

  static Future<BucketRegionsQuery> create({
    Endpoints? bucketHosts,
    bool useHttps = true,
    Duration? compactInterval,
    String? persistentFilePath,
    Duration? persistentInterval,
    void Function(Object, StackTrace)? persistentErrorHandler,
  }) async {
    return await _BucketRegionsQuery._create(
      bucketHosts: bucketHosts,
      useHttps: useHttps,
      compactInterval: compactInterval,
      persistentFilePath: persistentFilePath,
      persistentInterval: persistentInterval,
      persistentErrorHandler: persistentErrorHandler,
    );
  }
}

final class _BucketRegionsQuery implements BucketRegionsQuery {
  final Endpoints _bucketHosts;
  final cache_provider.CacheProvider<_V4QueryCacheValue> _cache;
  final bool _useHttps;
  final Dio _http;

  _BucketRegionsQuery(
    this._bucketHosts,
    this._cache,
    this._useHttps,
  ) : _http = Dio();

  static Future<_BucketRegionsQuery> _create({
    Endpoints? bucketHosts,
    bool useHttps = true,
    Duration? compactInterval,
    String? persistentFilePath,
    Duration? persistentInterval,
    void Function(Object, StackTrace)? persistentErrorHandler,
  }) async {
    final cache = await _createCache(
      compactInterval,
      persistentFilePath,
      persistentInterval,
      persistentErrorHandler,
    );
    return _BucketRegionsQuery(
      bucketHosts ?? Endpoints._defaultBucketEndpoints(),
      cache,
      useHttps,
    );
  }

  @override
  Future<RegionsProvider> query({
    required String accessKey,
    required String bucketName,
    bool accelerateUploading = false,
  }) async {
    final cacheKey =
        '$accessKey:$bucketName:${accelerateUploading ? '1' : '0'}:${_bucketHosts._cacheKey}';
    dynamic err;
    StackTrace? stackTrace;
    final (value, _) = await _cache.get(cacheKey, () async {
      try {
        final response = await _getUrl(
          _bucketHosts,
          'v4/query?ak=$accessKey&bucket=$bucketName',
          _protocol,
          _http,
        );
        return _V4QueryCacheValue.fromResponse(
          _V4QueryResponse._fromRaw(
            response,
            accelerateUploading,
          ),
        );
      } catch (e, s) {
        err = e;
        stackTrace = s;
        rethrow;
      }
    });
    if (value == null) {
      Error.throwWithStackTrace(err!, stackTrace!);
    }
    return value;
  }

  static Future<cache_provider.CacheProvider<_V4QueryCacheValue>> _createCache(
    Duration? compactInterval,
    String? persistentFilePath,
    Duration? persistentInterval,
    void Function(Object, StackTrace)? persistentErrorHandler,
  ) async {
    final compactIntervalS = compactInterval ?? Duration(seconds: 60);
    if (persistentFilePath == null) {
      return cache_provider.CacheProvider.createInMemoryCache<
          _V4QueryCacheValue>(compactIntervalS);
    }
    final persistentIntervalS = persistentInterval ?? Duration(seconds: 60);
    return cache_provider.CacheProvider.createPersistentCache<
        _V4QueryCacheValue>(
      persistentFilePath,
      compactIntervalS,
      persistentIntervalS,
      (cache) => jsonEncode(
        cache,
        toEncodable: (object) {
          if (object is cache_provider.CachePair<_V4QueryCacheValue>) {
            return {
              'createdAt': object.createdAt.toIso8601String(),
              'key': object.key,
              'value': object.data._toMap(),
            };
          } else {
            throw Exception('unexpected object type: $object');
          }
        },
      ),
      (line) => jsonDecode(
        line,
        reviver: (key, value) {
          if (key == 'value') {
            return _V4QueryCacheValue._fromMap(value as Map<String, dynamic>);
          } else if (key == 'createdAt') {
            return DateTime.parse(value as String);
          }
          return value;
        },
      ),
      (e, s) {
        if (persistentErrorHandler != null) {
          persistentErrorHandler(e, s);
        }
      },
    );
  }

  String get _protocol {
    if (_useHttps) {
      return Protocol.Https.value;
    } else {
      return Protocol.Http.value;
    }
  }
}

final class _V4QueryServiceHosts {
  final Endpoints _endpoints;

  _V4QueryServiceHosts.fromRaw(dynamic raw, bool accelerateUploading)
      : _endpoints = _fromRaw(raw, accelerateUploading);
  _V4QueryServiceHosts.fromEndpoint(this._endpoints);

  static Endpoints _fromRaw(dynamic raw, bool accelerateUploading) {
    List<String>? accelerated;
    if (accelerateUploading) {
      accelerated = _toStringList(raw['acc_domains']);
    }
    return Endpoints(
      accelerated: accelerated,
      preferred: _toStringList(raw['domains']),
      alternative: _toStringList(raw['old']),
    );
  }

  Endpoints get endpoints => _endpoints;
}

final class _V4QueryRegion {
  final int _ttl;
  final _V4QueryServiceHosts _up, _bucket;

  _V4QueryRegion({
    required int ttl,
    required _V4QueryServiceHosts up,
    required _V4QueryServiceHosts bucket,
  })  : _ttl = ttl,
        _up = up,
        _bucket = bucket;

  factory _V4QueryRegion._fromRaw(
    dynamic raw,
    bool accelerateUploading,
  ) {
    late final _V4QueryServiceHosts bucket;
    if (raw['uc'] == null) {
      bucket = _V4QueryServiceHosts.fromEndpoint(
        Endpoints._defaultBucketEndpoints(),
      );
    } else {
      bucket = _V4QueryServiceHosts.fromRaw(raw['uc'], accelerateUploading);
    }
    return _V4QueryRegion(
      ttl: raw['ttl'],
      bucket: bucket,
      up: _V4QueryServiceHosts.fromRaw(raw['up'], accelerateUploading),
    );
  }

  int get ttl => _ttl;
  _V4QueryServiceHosts get up => _up;
  _V4QueryServiceHosts get bucket => _bucket;
}

final class _V4QueryResponse {
  final List<_V4QueryRegion> _regions;

  _V4QueryResponse({
    required List<_V4QueryRegion> regions,
  }) : _regions = regions;

  factory _V4QueryResponse._fromRaw(
    dynamic raw,
    bool accelerateUploading,
  ) {
    final regions = <_V4QueryRegion>[];
    for (final host in raw['hosts']) {
      regions.add(_V4QueryRegion._fromRaw(host, accelerateUploading));
    }
    return _V4QueryResponse(regions: regions);
  }

  List<_V4QueryRegion> get regions => _regions;
}

final class _V4QueryCacheValue
    implements cache_provider.CacheValue, RegionsProvider {
  final List<Region> _regions;
  final DateTime _refreshAfter, _expiredAt;

  _V4QueryCacheValue(this._regions, this._refreshAfter, this._expiredAt);

  factory _V4QueryCacheValue.fromResponse(
    _V4QueryResponse response,
  ) {
    final regions = <Region>[];
    int minTtl = 2 ^ 53;
    for (final r in response._regions) {
      if (r._ttl < minTtl) {
        minTtl = r._ttl;
      }
      final region = Region(up: r._up._endpoints, bucket: r._bucket._endpoints);
      regions.add(region);
    }
    return _V4QueryCacheValue(
      regions,
      DateTime.now().add(Duration(seconds: minTtl ~/ 2)),
      DateTime.now().add(Duration(seconds: minTtl)),
    );
  }

  @override
  bool isValid() => DateTime.now().isBefore(_expiredAt);

  @override
  bool shouldRefresh() => DateTime.now().isAfter(_refreshAfter);

  @override
  List<Region> get regions => _regions;

  Map<String, dynamic> _toMap() {
    final regionMaps = <Map<String, dynamic>>[];
    for (final region in _regions) {
      regionMaps.add(region._toMap());
    }
    return {
      'regions': regionMaps,
      'expiredAt': _expiredAt.toIso8601String(),
      'refreshAfter': _refreshAfter.toIso8601String(),
    };
  }

  factory _V4QueryCacheValue._fromMap(Map<String, dynamic> map) =>
      _V4QueryCacheValue(
        _toRegionList(map['regions']),
        DateTime.parse(map['refreshAfter']),
        DateTime.parse(map['expiredAt']),
      );

  static List<Region> _toRegionList(dynamic raw) {
    final lr = <Region>[];
    for (final rawElement in raw) {
      lr.add(Region._fromMap(rawElement));
    }
    return lr;
  }
}
