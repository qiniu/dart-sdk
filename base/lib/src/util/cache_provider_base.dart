import 'package:mutex/mutex.dart';
import 'package:singleflight/singleflight.dart';

import 'dart:io';
import 'dart:convert';

// CacheValue is the abstract class used to represent the cached value
abstract class CacheValue {
  bool isValid();
  bool shouldRefresh();
}

// CacheEntry adds the createdAt field to CacheValue
final class CacheEntry<V extends CacheValue> implements CacheValue {
  final V _data;
  final DateTime _createdAt;

  V get data => _data;
  DateTime get createdAt => _createdAt;

  CacheEntry(this._data, this._createdAt);

  @override
  bool isValid() => _data.isValid();

  @override
  bool shouldRefresh() => _data.shouldRefresh();
}

// CachePair adds the key field to the CacheEntry to represent the cache key.
final class CachePair<V extends CacheValue> extends CacheEntry<V> {
  final String _key;
  String get key => _key;

  CachePair(this._key, V data, DateTime createdAt) : super(data, createdAt);
}

// GetResult represents the result of the cache getting
enum GetResult {
  // fromCache means the result is from the cache and the result is valid
  fromCache,
  // fromCache means the result is from the cache and the result is valid but need to refresh
  fromCacheAndRefreshAsync,
  // fromCache means the result is from the fallback
  fromFallback,
  // fromCache means the result is from the cache but the result is invalid
  fromInvalidCache,
  // none means failed to get the cache
  none
}

// CacheProvider provides the storage interface for the cache
abstract class CacheProvider<V extends CacheValue> {
  // get searches the cache to see if there is a cached value for the specified key,
  // and if there is and it is valid, it will return it directly.
  // If it doesn't, it will try to execute the fallback function to get the new cached value,
  // and if it does but is invalid, it will also try to get the new cached value from the fallback,
  //but if the fallback function throws an exception, it will return the invalid cached value.
  Future<(V?, GetResult)> get(
    String key,
    Future<V> Function() fallback,
  );

  // set sets the cached value directly
  Future<void> set(String key, V value);

  // clear emptys the cache and prevent the CacheProvider from being used any more,
  // Caution: clear() should only be called when you are sure that CacheProvider will not be used any more.
  Future<void> clear();

  // createInMemoryCache creates an in-memory cache with the ability to automatically asynchronously
  // compact the cache when it's invalid.
  static CacheProvider<V> createInMemoryCache<V extends CacheValue>(
    Duration compactInterval, {
    Map<String, CacheEntry<V>>? initMap,
  }) {
    return _InMemoryCache(compactInterval, initMap: initMap);
  }

  // createPersistentCache creates a persistent filesystem-based cache that loads previously saved cache values
  // from a file and periodically synchronizes them with the cached contents of the file thereafter.
  static Future<CacheProvider<V>> createPersistentCache<V extends CacheValue>(
    String cacheFilePath,
    Duration compactInterval,
    Duration persistentInterval,
    String Function(CachePair<V>) handleSerialize,
    CachePair<V> Function(String) handleDeserialize,
    void Function(Object, StackTrace) handleError,
  ) async {
    return _PersistentCache._create(
      cacheFilePath,
      compactInterval,
      persistentInterval,
      handleSerialize,
      handleDeserialize,
      handleError,
    );
  }
}

final class _InMemoryCache<V extends CacheValue> implements CacheProvider<V> {
  final Duration _compactInterval;
  final Map<String, CacheEntry<V>> _cacheMap;
  final Mutex _mutex;
  final Group<V> _group;

  bool _flushing, _stopFlushing;
  DateTime _lastCompactTime;

  _InMemoryCache(
    Duration compactInterval, {
    Map<String, CacheEntry<V>>? initMap,
  })  : _compactInterval = compactInterval,
        _cacheMap = initMap ?? {},
        _lastCompactTime = DateTime.now(),
        _mutex = Mutex(),
        _group = Group.create<V>(),
        _flushing = false,
        _stopFlushing = false;

  @override
  Future<(V?, GetResult)> get(String key, Future<V> Function() fallback) async {
    CacheEntry<V>? value;
    await _mutex.protect(() async {
      value = _cacheMap[key];
    });

    try {
      if (value != null && value!.isValid()) {
        if (value!.shouldRefresh()) {
          _refresh(key, fallback);
          return (value!._data, GetResult.fromCacheAndRefreshAsync);
        } else {
          return (value!._data, GetResult.fromCache);
        }
      }

      try {
        final newValue = await _refresh(key, fallback);
        return (newValue, GetResult.fromFallback);
      } catch (e) {
        if (value != null) {
          return (value!._data, GetResult.fromInvalidCache);
        } else {
          return (null, GetResult.none);
        }
      }
    } finally {
      _flush();
    }
  }

  @override
  Future<void> set(String key, V value) async {
    return await _set(key, value, true);
  }

  @override
  Future<void> clear() async {
    await _mutex.protect(() async {
      _cacheMap.clear();
      _lastCompactTime = DateTime.now();
      _stopFlushing = true;
    });
  }

  Future<V> _refresh(String key, Future<V> Function() fallback) async {
    final newValue = await _group.doGroup(key, fallback);
    await _set(key, newValue, false);
    return newValue;
  }

  Future<void> _set(String key, V value, bool willFlushAsync) async {
    if (value.isValid()) {
      final now = DateTime.now();
      await _mutex.protect(() async {
        _cacheMap[key] = CacheEntry(value, now);
      });
      if (willFlushAsync) {
        _flush();
      }
    }
  }

  Future<void> _flush() async {
    try {
      if (_flushing || _stopFlushing) {
        return;
      }
      _flushing = true;
      await _doFlush();
    } finally {
      _flushing = false;
    }
  }

  Future<void> _doFlush() async {
    if (_lastCompactTime.add(_compactInterval).isBefore(DateTime.now())) {
      await _doCompact();
      _lastCompactTime = DateTime.now();
    }
  }

  Future<void> _doCompact() async {
    await _mutex.protect(() async {
      final toDeleted = <String>[];
      _cacheMap.forEach((key, value) {
        if (!value.isValid()) {
          toDeleted.add(key);
        }
      });
      for (var key in toDeleted) {
        _cacheMap.remove(key);
      }
    });
  }
}

final class _PersistentCache<V extends CacheValue> extends _InMemoryCache<V> {
  final String _cacheFilePath;
  final Duration _persistentInterval;
  final CachePair<V> Function(String) _deserializeHandler;
  final String Function(CachePair<V>) _serializeHandler;
  final void Function(Object, StackTrace) _errorHandler;

  DateTime _lastPersistentTime;

  _PersistentCache(
    this._cacheFilePath,
    Duration compactInterval,
    this._persistentInterval,
    this._serializeHandler,
    this._deserializeHandler,
    this._errorHandler, {
    Map<String, CacheEntry<V>>? initMap,
  })  : _lastPersistentTime = DateTime.now(),
        super(compactInterval, initMap: initMap);

  static Future<CacheProvider<V>> _create<V extends CacheValue>(
    String cacheFilePath,
    Duration compactInterval,
    Duration persistentInterval,
    String Function(CachePair<V>) handleSerialize,
    CachePair<V> Function(String) handleDeserialize,
    void Function(Object, StackTrace) handleError,
  ) async {
    await _ensureFileExists(cacheFilePath);
    final lockFile = await _lockCachePersistentFile(cacheFilePath, true);
    try {
      final loadedMap =
          await _loadCacheMapFrom(cacheFilePath, handleDeserialize, null);
      return _PersistentCache(
        cacheFilePath,
        compactInterval,
        persistentInterval,
        handleSerialize,
        handleDeserialize,
        handleError,
        initMap: loadedMap,
      );
    } finally {
      await _unlockCachePersistentFile(lockFile);
    }
  }

  @override
  Future<void> clear() async {
    final lockFile = await _lockCachePersistentFile(_cacheFilePath, true);
    try {
      super.clear();
      await File(_cacheFilePath).delete();
    } finally {
      await _unlockCachePersistentFile(lockFile);
    }
  }

  @override
  Future<void> _doFlush() async {
    await super._doFlush();

    if (_lastPersistentTime.add(_persistentInterval).isBefore(DateTime.now())) {
      await _doPersistent();
      _lastPersistentTime = DateTime.now();
    }
  }

  Future<void> _doPersistent() async {
    await _ensureFileExists(_cacheFilePath);
    final lockFile = await _lockCachePersistentFile(_cacheFilePath, true);
    try {
      final loadedMap = await _loadCacheMapFrom(
        _cacheFilePath,
        _deserializeHandler,
        _errorHandler,
      );
      if (_isCacheMapEqual(_cacheMap, loadedMap)) {
        return;
      }
      _mergeCacheMapFrom(loadedMap);
      await _writeCacheMap();
    } catch (e, s) {
      _errorHandler(e, s);
    } finally {
      await _unlockCachePersistentFile(lockFile);
    }
  }

  static Future<RandomAccessFile> _lockCachePersistentFile(
    String cacheFilePath,
    bool exclusive,
  ) async {
    final lockFilePath = '$cacheFilePath.lock';
    await _ensureFileExists(lockFilePath);
    final randomAccessFile =
        await File(lockFilePath).open(mode: FileMode.write);
    late final FileLock lockMode;
    if (exclusive) {
      lockMode = FileLock.blockingExclusive;
    } else {
      lockMode = FileLock.blockingShared;
    }
    return await randomAccessFile.lock(lockMode);
  }

  static Future<void> _unlockCachePersistentFile(RandomAccessFile file) async {
    await file.unlock();
    await file.close();
  }

  static Future<void> _ensureFileExists(
    String filePath,
  ) async {
    await File(filePath).create(recursive: true);
  }

  static Future<Map<String, CacheEntry<V>>>
      _loadCacheMapFrom<V extends CacheValue>(
    String cacheFilePath,
    CachePair<V> Function(String) handleDeserialize,
    void Function(Object, StackTrace)? handleError,
  ) async {
    final Map<String, CacheEntry<V>> m = {};
    try {
      var stream = File(cacheFilePath).openRead();
      if (handleError != null) {
        stream = stream.handleError(handleError);
      }
      await stream.map(utf8.decode).transform(LineSplitter()).forEach((line) {
        final cachePair = handleDeserialize(line);
        if (cachePair.isValid()) {
          m[cachePair.key] = cachePair;
        }
      });
      return m;
    } catch (e) {
      return m;
    }
  }

  static bool _isCacheMapEqual<V extends CacheValue>(
    Map<String, CacheEntry<V>> left,
    Map<String, CacheEntry<V>> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in right.entries) {
      if (left[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  void _mergeCacheMapFrom(Map<String, CacheEntry<V>> right) {
    for (final entry in right.entries) {
      if (!entry.value.data.isValid()) {
        continue;
      }
      final cacheValue = _cacheMap[entry.key];
      if (cacheValue != null) {
        if (cacheValue.createdAt.isBefore(entry.value.createdAt)) {
          _cacheMap[entry.key] = entry.value;
        }
      } else {
        _cacheMap[entry.key] = entry.value;
      }
    }
  }

  Future<void> _writeCacheMap() async {
    try {
      final sink = File(_cacheFilePath).openWrite(mode: FileMode.writeOnly);
      try {
        sink.done.catchError(_errorHandler);
        for (final entry in _cacheMap.entries) {
          sink.writeln(
            _serializeHandler(
              CachePair(entry.key, entry.value.data, entry.value.createdAt),
            ),
          );
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
    } catch (e) {
      // do nothing
    }
  }
}
