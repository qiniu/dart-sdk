part of 'config.dart';

abstract class AbstractCacheProvider {
  void setItem(String key, String item);
  String getItem(String key);

  /// 删除指定 key 的缓存
  void removeItem(String key);

  /// 清除所有
  void clear();
}

class CacheProvider extends AbstractCacheProvider {
  @override
  String getItem(String key) {
    return null;
  }

  @override
  void setItem(String key, String item) {}

  @override
  void removeItem(String key) {}

  @override
  void clear() {}
}
