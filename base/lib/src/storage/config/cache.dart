part of 'config.dart';

abstract class CacheProvider {
  /// 设置一对数据
  Future setItem(String key, String item);

  /// 根据 key 获取缓存
  Future<String> getItem(String key);

  /// 删除指定 key 的缓存
  Future removeItem(String key);

  /// 清除所有
  Future clear();
}

class DefaultCacheProvider extends CacheProvider {
  Map<String, String> value = {};

  @override
  Future clear() async {
    value.clear();
  }

  @override
  Future<String> getItem(String key) async {
    return value[key];
  }

  @override
  Future removeItem(String key) async {
    value.remove(key);
  }

  @override
  Future setItem(String key, String item) async {
    value[key] = item;
  }
}
