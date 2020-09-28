part of 'config.dart';

abstract class AbstractCacheProvider {
  void setItem(String key, String item);
  String getItem(String key);
}

class CacheProvider extends AbstractCacheProvider {
  @override
  String getItem(String key) {
    return null;
  }

  @override
  void setItem(String key, String item) {}
}
