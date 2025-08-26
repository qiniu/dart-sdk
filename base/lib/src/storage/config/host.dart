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
  final _stashedUpHosts = <_Host>[];
  // accessKey:bucket 用此 key 判断是否 up host 需要走缓存
  String? _cacheKey;

  Future<List<_Host>> getUpHostsFromV4Query({
    required String accessKey,
    required String bucket,
    bool accelerateUploading = false,
  }) async {
    final upHosts = <_Host>[];
    final cacheKey = '$accessKey:'
        '$bucket:'
        '${accelerateUploading ? '1' : '0'}:'
        '${_getHostsMD5(bucketHosts)}';
    if (cacheKey == _cacheKey && _stashedUpHosts.isNotEmpty) {
      upHosts.addAll(_stashedUpHosts);
    } else {
      final data = await _getUrl(
        bucketHosts,
        'v4/query?ak=$accessKey&bucket=$bucket',
        protocol,
        _http,
      );
      final hosts = data['hosts']
          .map((dynamic json) => _Host.fromJson(json as Map))
          .cast<_Host>();
      if (hosts.isEmpty) _throwNoAvailableRegionError();

      _cacheKey = cacheKey;
      _stashedUpHosts.addAll(hosts);
    }
    return upHosts;
  }

  @override
  Future<String> getUpHost({
    required String accessKey,
    required String bucket,
    bool accelerateUploading = false,
    // 表单上传这个值为true，则始终在所有可用区域之间选择一个可用域名
    // 分片上传为false，则始终选择 regionIndex 指定的区域
    bool transregional = false,
    int regionIndex = 0,
  }) async {
    _unfreezeUpDomains();

    final upHosts = await getUpHostsFromV4Query(
      accessKey: accessKey,
      bucket: bucket,
      accelerateUploading: accelerateUploading,
    );

    if (transregional) {
      // 表单上传
      final upDomains = <_Domain>{};
      // 全都不可用了，随机选择一个域名返回
      for (final host in upHosts) {
        final domainList = host.up['domains'].cast<String>() as List<String>;
        final domains = domainList.map((domain) => _Domain(domain));
        upDomains.addAll(domains);
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
      return '$protocol://${upDomains.toList().mustGetRandomElement()}';
    } else {
      // 分片上传
      if (regionIndex < upHosts.length) {
        // 分片上传不能随机选择一个域名返回，需要上层切换regionIndex
        _throwNoAvailableHostError();
      } else {
        // 已经至少把所有的可用region都尝试过了，直接继续轮转回开头的region
        final host = upHosts.elementAt(regionIndex % upHosts.length);
        // 在这个region里面随机选择一个域名返回
        final domainList = host.up['domains'].cast<String>() as List<String>;
        final domains = domainList.map((domain) => _Domain(domain));
        return '$protocol://${domains.toList().mustGetRandomElement()}';
      }
    }
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
    // 表单上传这个值为true，则始终在所有可用区域之间选择一个可用域名
    // 分片上传为false，则始终选择 regionIndex 指定的区域
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

    if (transregional) {
      // 表单上传
      final regions = regionsProvider.regions;
      if (regions.isEmpty) _throwNoAvailableRegionError();

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
      // 全都不可用了，随机选择一个域名返回
      return regions
          .mustGetRandomElement()
          .up
          .map((domain) => _makeHost(domain, useHttps: _useHttps))
          .toList()
          .mustGetRandomElement();
    } else {
      // 分片上传
      if (regionIndex < regionsProvider.regions.length) {
        final unfrozenDomain = regionsProvider.regions
            .elementAt(regionIndex)
            .up
            .map((domain) => _makeHost(domain, useHttps: _useHttps))
            .firstWhere(
              (domain) => !isFrozen(domain),
              orElse: () => '',
            );
        if (unfrozenDomain != '') {
          return unfrozenDomain;
        }
        // 分片上传不能随机选择一个域名返回，需要上层切换regionIndex
        _throwNoAvailableHostError();
      } else {
        // 已经至少把所有的可用region都尝试过了，直接继续轮转回开头的region
        final index = regionIndex % regionsProvider.regions.length;
        // 这里面的域名很可能都是仍然处于冻结状态的，这里随机选择一个返回
        return regionsProvider.regions
            .elementAt(index)
            .up
            .map((domain) => _makeHost(domain, useHttps: _useHttps))
            .toList()
            .mustGetRandomElement();
      }
    }
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
