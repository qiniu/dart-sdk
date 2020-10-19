part of 'put_parts_task.dart';

/// 分片上传用到的缓存 mixin
///
/// 分片上传的初始化文件、上传分片都应该以此实现缓存控制策略
mixin CacheMixin<T> on RequestTask<T> {
  String get _cacheKey;

  void clearCache() {
    config.cacheProvider.removeItem(_cacheKey);
  }

  void setCache(String data) {
    config.cacheProvider.setItem(_cacheKey, data);
  }

  String getCache() {
    return config.cacheProvider.getItem(_cacheKey);
  }
}
