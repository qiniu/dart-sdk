part of 'put_parts_task.dart';

/// 分片上传用到的缓存 mixin
///
/// 分片上传的初始化文件、上传分片都应该以此实现缓存控制策略
mixin CacheMixin<T> on RequestTask<T> {
  String get _cacheKey;

  Future clearCache() async {
    await config.cacheProvider.removeItem(_cacheKey);
  }

  Future<void> setCache(String data, {int? expireAt}) async {
    final cacheItem = _CacheItem(data, expireAt: expireAt ?? 0);
    await config.cacheProvider.setItem(_cacheKey, cacheItem._toCacheString());
  }

  Future<String?> getCache() async {
    final cacheString = await config.cacheProvider.getItem(_cacheKey);
    final cacheItem = _CacheItem.fromCacheString(cacheString);
    if (cacheItem == null) {
      return null;
    }

    if (cacheItem.isExpired) {
      await config.cacheProvider.removeItem(_cacheKey);
      return null;
    }

    return cacheItem.data;
  }
}

class _CacheItem {
  final String data;
  // 单位：毫秒
  final int expireAt;

  _CacheItem(this.data, {this.expireAt = 0});

  static _CacheItem? fromCacheString(String? cacheString) {
    if (cacheString == null) {
      return null;
    }
    try {
      final cacheMap = jsonDecode(cacheString) as Map<String, dynamic>;
      return _CacheItem(
        cacheMap['data'] as String,
        expireAt: cacheMap['expireAt'] as int,
      );
    } catch (e) {
      // 解析失败说明缓存数据有问题，直接当做过期缓存处理
      return _CacheItem('', expireAt: -1);
    }
  }

  String _toCacheString() {
    final cacheMap = {
      'data': data,
      'expireAt': expireAt,
    };
    return jsonEncode(cacheMap);
  }

  bool get isExpired {
    if (expireAt == 0) {
      return false;
    }
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    return currentTime >= expireAt;
  }
}
