part of 'config.dart';

abstract class CacheProvider {
  /// 设置一对数据
  void setItem(String key, String item);

  /// 根据 key 获取缓存
  String? getItem(String key);

  /// 删除指定 key 的缓存
  void removeItem(String key);

  /// 清除所有
  void clear();
}

class DefaultCacheProvider extends CacheProvider {
  Map<String, String> value = {};

  @override
  void clear() {
    value.clear();
  }

  @override
  String? getItem(String key) {
    return value[key];
  }

  @override
  void removeItem(String key) {
    value.remove(key);
  }

  @override
  void setItem(String key, String item) {
    value[key] = item;
  }
}
