part of 'config.dart';

abstract class HostProvider {
  Future<String> getUpHost({
    required String accessKey,
    required String bucket,
    bool accelerateUploading = false,
    bool transregional = false,
    int regionIndex = 0,
  });

  bool isFrozen(String host);

  void freezeHost(String host);
}

List<String> _defaultBucketHosts = [
  'uc.qiniuapi.com',
  'kodo-config.qiniuapi.com',
  'uc.qbox.me',
];

abstract class HostFreezer extends HostProvider {
  // 冻结的上传区域
  final List<_Domain> _frozenUpDomains = [];

  @override
  bool isFrozen(String host) {
    final uri = Uri.parse(host);
    final frozenDomain = _frozenUpDomains.where(
      (domain) =>
          domain.isFrozen() && domain.value == '${uri.host}:${uri.port}',
    );
    return frozenDomain.isNotEmpty;
  }

  @override
  void freezeHost(String host) {
    // http://example.org
    // scheme: http
    // host: example.org
    final uri = Uri.parse(host);
    _frozenUpDomains.add(_Domain('${uri.host}:${uri.port}')..freeze());
  }

  void _unfreezeUpDomains() {
    // 解冻需要被解冻的 host
    _frozenUpDomains.removeWhere((domain) => !domain.isFrozen());
  }
}

class DefaultHostProvider extends HostFreezer {
  var protocol = Protocol.Https.value;
  var bucketHosts = _defaultBucketHosts;

  final _http = Dio();
  // 缓存的上传区域
  final _stashedUpDomains = <_Domain>[];
  // accessKey:bucket 用此 key 判断是否 up host 需要走缓存
  String? _cacheKey;

  @override
  Future<String> getUpHost({
    required String accessKey,
    required String bucket,
    bool accelerateUploading = false,
    bool transregional = false,
    int regionIndex = 0,
  }) async {
    _unfreezeUpDomains();
    final upDomains = <_Domain>[];
    final cacheKey =
        '$accessKey:$bucket:${accelerateUploading ? '1' : '0'}:${_getHostsMD5(bucketHosts)}';
    if (cacheKey == _cacheKey && _stashedUpDomains.isNotEmpty) {
      upDomains.addAll(_stashedUpDomains);
    } else {
      final data = await _getUrl(
        bucketHosts,
        'v4/query?ak=$accessKey&bucket=$bucket',
        protocol,
        _http,
      );
      Iterable<_Host> hosts = data['hosts']
          .map((dynamic json) => _Host.fromJson(json as Map))
          .cast<_Host>();

      if (!transregional) {
        final host = hosts.elementAtOrNull(regionIndex);
        if (host == null) {
          _throwNoAvailableRegionError();
        }
        hosts = [host];
      }

      for (final host in hosts) {
        final domainList = host.up['domains'].cast<String>() as List<String>;
        final domains = domainList.map((domain) => _Domain(domain));
        upDomains.addAll(domains);
      }

      _cacheKey = cacheKey;
      _stashedUpDomains.addAll(upDomains);
    }

    // 每次都从头遍历一遍，最合适的 host 总是会排在最前面
    for (var index = 0; index < upDomains.length; index++) {
      final availableDomain = upDomains.elementAt(index);
      // 检查看起来可用的 host 是否之前被冻结过
      final frozen = isFrozen('$protocol://${availableDomain.value}');

      if (!frozen) {
        return '$protocol://${availableDomain.value}';
      }
    }
    _throwNoAvailableHostError();
  }
}

class _Host {
  late final String region;
  late final int ttl;
  // domains: []
  late final Map<String, dynamic> up;

  _Host({required this.region, required this.ttl, required this.up});

  factory _Host.fromJson(Map json) {
    return _Host(
      region: json['region'] as String,
      ttl: json['ttl'] as int,
      up: json['up'] as Map<String, dynamic>,
    );
  }
}

class _Domain {
  int frozenTime = 0;
  final _lockTime = 1000 * 60 * 10;
  final String value;

  bool isFrozen() =>
      frozenTime + _lockTime > DateTime.now().millisecondsSinceEpoch;

  void freeze() {
    frozenTime = DateTime.now().millisecondsSinceEpoch;
  }

  _Domain(this.value);
}

class DefaultHostProviderV2 extends HostFreezer {
  BucketRegionsQuery? _query;
  final Endpoints _bucketHosts;
  final bool _useHttps;
  final _group = singleflight.Group.create<BucketRegionsQuery>();

  DefaultHostProviderV2()
      : _bucketHosts = Endpoints._defaultBucketEndpoints(),
        _useHttps = true;

  DefaultHostProviderV2.from({
    required Endpoints bucketHosts,
    bool useHttps = true,
  })  : _bucketHosts = bucketHosts,
        _useHttps = useHttps;

  @override
  Future<String> getUpHost({
    required String accessKey,
    required String bucket,
    bool accelerateUploading = false,
    bool transregional = false,
    int regionIndex = 0,
  }) async {
    _unfreezeUpDomains();

    final query = await _getQuery();
    final regionsProvider = await query.query(
      accessKey: accessKey,
      bucketName: bucket,
      accelerateUploading: accelerateUploading,
    );
    final regions = <Region>[];
    if (transregional) {
      regions.addAll(regionsProvider.regions);
    } else {
      final region = regionsProvider.regions.elementAtOrNull(regionIndex);
      if (region == null) {
        _throwNoAvailableRegionError();
      }
      regions.add(region);
    }
    for (final region in regions) {
      final unfrozenDomain = region.up
          .map((domain) => _makeHost(domain, useHttps: _useHttps))
          .firstWhere(
            (domain) => !isFrozen(domain),
            orElse: () => '',
          );
      if (unfrozenDomain != '') {
        return unfrozenDomain;
      }
    }
    _throwNoAvailableHostError();
  }

  Future<BucketRegionsQuery> get query => _getQuery();

  Future<BucketRegionsQuery> _getQuery() async {
    if (_query != null) {
      return _query!;
    }
    _query = await _group.doGroup(
      '',
      () async => BucketRegionsQuery.create(
        bucketHosts: _bucketHosts,
        useHttps: _useHttps,
        persistentFilePath: platform.isWeb // web端不要持久化到磁盘，内部自动使用内存缓存即可
            ? null
            : join(
                Directory.systemTemp.path,
                'qiniu-dart-sdk',
                'regions_v4_01.cache.json',
              ),
      ),
    );
    return _query!;
  }
}

String _getHostsMD5(List<String> hosts) {
  final output = AccumulatorSink<Digest>();
  final input = md5.startChunkedConversion(output);

  for (final host in hosts) {
    input.add(utf8.encode(host));
  }
  input.close();
  return output.events.single.toString();
}

Future<Map> _getUrl(
  Iterable<String> domains,
  String path,
  String protocol,
  Dio http,
) async {
  DioException? err;
  for (var domain in domains) {
    final url =
        domain.contains('://') ? '$domain/$path' : '$protocol://$domain/$path';
    try {
      final resp = await http.get<Map>(url);
      _checkResponse(resp);
      return resp.data!;
    } on DioException catch (e) {
      if (e.response?.statusCode != null &&
          e.response!.statusCode! >= 400 &&
          e.response!.statusCode! < 500) {
        rethrow;
      }
      err = e;
    }
  }
  throw err!;
}

void _checkResponse(Response response) {
  if (response.headers['x-reqid'] == null &&
      response.headers['x-log'] == null) {
    throw DioException.connectionError(
      requestOptions: response.requestOptions,
      reason: 'response might be malicious',
    );
  }
}

Never _throwNoAvailableHostError() {
  throw StorageError(
    type: StorageErrorType.NO_AVAILABLE_HOST,
    message: '没有可用的上传域名',
  );
}

Never _throwNoAvailableRegionError() {
  throw StorageError(
    type: StorageErrorType.NO_AVAILABLE_REGION,
    message: '没有可用的上传区域',
  );
}
