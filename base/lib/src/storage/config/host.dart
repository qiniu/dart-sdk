part of 'config.dart';

abstract class HostProvider {
  Future<String> getUpHost({
    @required String accessKey,
    @required String bucket,
  });

  bool isFrozen(String host);

  void freezeHost(String host);
}

class DefaultHostProvider extends HostProvider {
  final protocol = Protocol.Https.value;

  final _http = Dio();
  // 缓存的上传区域
  final _stashedUpDomains = <_Domain>[];
  // 缓存之前的 bucket 用于判断是否需要走缓存
  String _prevBucket;
  // 冻结的上传区域
  final List<_Domain> _frozenUpDomains = [];

  @override
  Future<String> getUpHost({
    @required String accessKey,
    @required String bucket,
  }) async {
    // 解冻需要被解冻的 host
    _frozenUpDomains.removeWhere((domain) => !domain.isFrozen());

    var _upDomains = <_Domain>[];
    if (bucket == _prevBucket && _stashedUpDomains.isNotEmpty) {
      _upDomains.addAll(_stashedUpDomains);
    } else {
      final url =
          '$protocol://api.qiniu.com/v4/query?ak=$accessKey&bucket=$bucket';

      final res = await _http.get<Map>(url);
      final hosts = res.data['hosts']
          .map((dynamic json) => _Host.fromJson(json as Map))
          .cast<_Host>()
          .toList() as List<_Host>;

      for (var host in hosts) {
        final domainList = host.up['domains'].cast<String>() as List<String>;
        final domains = domainList.map((domain) => _Domain(domain));
        _upDomains.addAll(domains);
      }

      _prevBucket = bucket;
    }

    // 每次都从头遍历一遍，bucket 所在的区域的 host 总是会排在最前面
    // TODO 按照客户端所在区域选择更适合 ta 的 host
    for (var index = 0; index < _upDomains.length; index++) {
      final availableDomain = _upDomains.elementAt(index);
      // 检查看起来可用的 host 是否之前被冻结过
      final fronzenUpDomain = _frozenUpDomains.firstWhere(
        (domain) => domain.isFrozen() && domain.value == availableDomain.value,
        orElse: () => null,
      );
      if (fronzenUpDomain == null) {
        return protocol + '://' + availableDomain.value;
      }
    }
    // 全部被冻结，几乎不存在的情况
    throw StorageError(type: StorageErrorType.UNKNOWN, message: '没有可用的服务器');
  }

  @override
  bool isFrozen(String host) {
    final uri = Uri.parse(host);
    final frozenDomain = _frozenUpDomains
        .firstWhere((domain) => domain.value == uri.host, orElse: () => null);
    return frozenDomain != null;
  }

  @override
  void freezeHost(String host) {
    // http://example.org
    // scheme: http
    // host: example.org
    final uri = Uri.parse(host);
    _frozenUpDomains.add(_Domain(uri.host)..freeze());
  }

  // @override
  // void unfreezeHost(String host) {
  //   final uri = Uri.parse(host);
  //   final domain = _frozenUpDomains
  //       .firstWhere((domain) => domain.value == uri.host, orElse: () => null);

  //   if (domain != null) {
  //     _frozenUpDomains.remove(domain);
  //   }
  // }
}

class _Host {
  String region;
  int ttl;
  // domains: []
  Map<String, dynamic> up;

  _Host({this.region, this.ttl, this.up});

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

  bool isFrozen() {
    return frozenTime + _lockTime > DateTime.now().millisecond;
  }

  void freeze() {
    frozenTime = DateTime.now().millisecond;
  }

  String value;
  _Domain(this.value);
}
