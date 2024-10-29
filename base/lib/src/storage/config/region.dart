part of 'config.dart';

abstract class RegionsProvider {
  List<Region> getRegions();
}

final class Region implements RegionsProvider {
  final Endpoints _up, _bucket;

  Region({required Endpoints up, Endpoints? bucket})
      : _up = up,
        _bucket = bucket ?? Endpoints._defaultBucketEndpoints();

  Endpoints get up => _up;
  Endpoints get bucket => _bucket;

  @override
  List<Region> getRegions() {
    return [this];
  }

  Region.getByID(String regionId, {bool useHttps = true})
      : this(up: Endpoints._getUpEndpointsByID(regionId, useHttps: useHttps));
}

abstract class EndpointsProvider {
  Endpoints getEndpoints();
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

  List<String> get preferred => _preferred;
  List<String> get alternative => _alternative;
  List<String> get accelerated => _accelerated;

  @override
  Endpoints getEndpoints() {
    return this;
  }

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

  static String _makeHost(String domain, {bool useHttps = true}) {
    if (useHttps) {
      return 'https://$domain';
    } else {
      return 'http://$domain';
    }
  }

  static Endpoints _defaultBucketEndpoints() {
    return Endpoints(
      preferred: [
        _makeHost('uc.qiniuapi.com'),
        _makeHost('kodo-config.qiniuapi.com'),
      ],
      alternative: [
        _makeHost('uc.qbox.me'),
      ],
    );
  }

  @override
  Iterator<String> get iterator => _EndpointsIterator(this);

  Endpoints operator +(Endpoints right) {
    return Endpoints(
      accelerated: _accelerated + right._accelerated,
      preferred: _preferred + right.preferred,
      alternative: right.alternative,
    );
  }
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
