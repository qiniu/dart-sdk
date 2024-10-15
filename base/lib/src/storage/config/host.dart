part of 'config.dart';

abstract class HostProvider {
  Future<String> getUpHost({
    required String accessKey,
    required String bucket,
  });

  bool isFrozen(String host);

  void freezeHost(String host);
}

class DefaultHostProvider extends HostProvider {
  var protocol = Protocol.Https.value;
  var bucketHosts = [
    'uc.qiniuapi.com',
    'kodo-config.qiniuapi.com',
    'uc.qbox.me',
  ];

  final _http = Dio();
  // 缓存的上传区域
  final _stashedUpDomains = <_Domain>[];
  // accessKey:bucket 用此 key 判断是否 up host 需要走缓存
  String? _cacheKey;
  // 冻结的上传区域
  final List<_Domain> _frozenUpDomains = [];

  @override
  Future<String> getUpHost({
    required String accessKey,
    required String bucket,
  }) async {
    // 解冻需要被解冻的 host
    _frozenUpDomains.removeWhere((domain) => !domain.isFrozen());

    final upDomains = <_Domain>[];
    final cacheKey = '$accessKey:$bucket:${_getHostsMD5(bucketHosts)}';
    if (cacheKey == _cacheKey && _stashedUpDomains.isNotEmpty) {
      upDomains.addAll(_stashedUpDomains);
    } else {
      final data =
          await _getUrl(bucketHosts, 'v4/query?ak=$accessKey&bucket=$bucket');
      final hosts = data['hosts']
          .map((dynamic json) => _Host.fromJson(json as Map))
          .cast<_Host>()
          .toList() as List<_Host>;

      for (var host in hosts) {
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
    // 全部被冻结，几乎不存在的情况
    throw StorageError(
      type: StorageErrorType.NO_AVAILABLE_HOST,
      message: '没有可用的上传域名',
    );
  }

  @override
  bool isFrozen(String host) {
    final uri = Uri.parse(host);
    final frozenDomain = _frozenUpDomains
        .where((domain) => domain.isFrozen() && domain.value == uri.host);
    return frozenDomain.isNotEmpty;
  }

  @override
  void freezeHost(String host) {
    // http://example.org
    // scheme: http
    // host: example.org
    final uri = Uri.parse(host);
    _frozenUpDomains.add(_Domain(uri.host)..freeze());
  }

  Future<Map> _getUrl(List<String> domains, String path) async {
    DioException? err;
    for (final domain in domains) {
      final url = '$protocol://$domain/$path';
      try {
        final resp = await _http.get<Map>(url);
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

  bool isFrozen() {
    return frozenTime + _lockTime > DateTime.now().millisecondsSinceEpoch;
  }

  void freeze() {
    frozenTime = DateTime.now().millisecondsSinceEpoch;
  }

  _Domain(this.value);
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
