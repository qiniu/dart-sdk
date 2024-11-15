part of 'config.dart';

abstract class RegionsProvider {
  List<Region> get regions;
}

final class Region implements RegionsProvider {
  final Endpoints up, bucket;

  Region({required this.up, Endpoints? bucket})
      : bucket = bucket ?? Endpoints._defaultBucketEndpoints();

  @override
  List<Region> get regions => [this];

  Region.getByID(String regionId, {bool useHttps = true})
      : this(up: Endpoints._getUpEndpointsByID(regionId, useHttps: useHttps));

  factory Region._fromMap(Map<String, dynamic> map) => Region(
        up: Endpoints._fromMap(map['up']),
        bucket: Endpoints._fromMap(map['bucket']),
      );

  Map<String, dynamic> _toMap() => {
        'up': up._toMap(),
        'bucket': bucket._toMap(),
      };
}

abstract class EndpointsProvider {
  Endpoints get endpoints;
}

final class Endpoints extends Iterable<String> implements EndpointsProvider {
  final List<String> _preferred, _alternative, _accelerated;

  Endpoints({
    List<String>? preferred,
    List<String>? alternative,
    List<String>? accelerated,
  })  : _preferred = preferred ?? [],
        _alternative = alternative ?? [],
        _accelerated = accelerated ?? [];

  List<String> get preferred => List.unmodifiable(_preferred);
  List<String> get alternative => List.unmodifiable(_alternative);
  List<String> get accelerated => List.unmodifiable(_accelerated);

  @override
  Endpoints get endpoints => this;

  factory Endpoints._fromMap(Map<String, dynamic> map) => Endpoints(
        accelerated: _toStringList(map['accelerated']),
        preferred: _toStringList(map['preferred']),
        alternative: _toStringList(map['alternative']),
      );

  Map<String, dynamic> _toMap() => {
        'accelerated': _accelerated,
        'preferred': _preferred,
        'alternative': _alternative,
      };

  Endpoints._getUpEndpointsByID(String regionId, {bool useHttps = true})
      : _preferred = [
          _makeHost('upload-$regionId.qiniup.com', useHttps: useHttps),
          _makeHost('up-$regionId.qiniup.com', useHttps: useHttps),
        ],
        _alternative = [],
        _accelerated = [];

  @override
  int get length =>
      _accelerated.length + _preferred.length + _alternative.length;

  static Endpoints _defaultBucketEndpoints() => Endpoints(
        preferred: [
          _makeHost('uc.qiniuapi.com'),
          _makeHost('kodo-config.qiniuapi.com'),
        ],
        alternative: [
          _makeHost('uc.qbox.me'),
        ],
      );

  @override
  Iterator<String> get iterator => _EndpointsIterator(this);

  Endpoints operator +(Endpoints right) => Endpoints(
        accelerated: _accelerated + right._accelerated,
        preferred: _preferred + right.preferred,
        alternative: right.alternative,
      );

  String get _cacheKey =>
      '${_getHostsMD5(_accelerated)}:${_getHostsMD5(_preferred)}:${_getHostsMD5(_alternative)}';
}

enum _EndpointsIteratorStatus {
  accelerated,
  preferred,
  alternative,
}

final class _EndpointsIterator implements Iterator<String> {
  final Endpoints _endpoints;
  int _index;
  _EndpointsIteratorStatus _currentStatus;

  _EndpointsIterator(this._endpoints)
      : _index = -1,
        _currentStatus = _EndpointsIteratorStatus.accelerated;
  @override
  String get current {
    switch (_currentStatus) {
      case _EndpointsIteratorStatus.accelerated:
        return _endpoints.accelerated[_index];
      case _EndpointsIteratorStatus.preferred:
        return _endpoints.preferred[_index];
      case _EndpointsIteratorStatus.alternative:
        return _endpoints.alternative[_index];
    }
  }

  @override
  bool moveNext() {
    while (true) {
      switch (_currentStatus) {
        case _EndpointsIteratorStatus.accelerated:
          if ((_index + 1) >= _endpoints.accelerated.length) {
            _currentStatus = _EndpointsIteratorStatus.preferred;
            _index = -1;
            continue;
          }
          _index += 1;
          return true;
        case _EndpointsIteratorStatus.preferred:
          if ((_index + 1) >= _endpoints.preferred.length) {
            _currentStatus = _EndpointsIteratorStatus.alternative;
            _index = -1;
            continue;
          }
          _index += 1;
          return true;
        case _EndpointsIteratorStatus.alternative:
          if ((_index + 1) >= _endpoints.alternative.length) {
            return false;
          }
          _index += 1;
          return true;
      }
    }
  }
}

List<String>? _toStringList(dynamic raw) {
  final ls = <String>[];
  if (raw == null) {
    return null;
  }
  for (final rawElement in raw) {
    ls.add(rawElement);
  }
  return ls;
}

String _makeHost(String domain, {bool useHttps = true}) {
  if (domain.contains('://')) {
    return domain;
  }
  if (useHttps) {
    return 'https://$domain';
  } else {
    return 'http://$domain';
  }
}
