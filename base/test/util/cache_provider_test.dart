import 'package:qiniu_sdk_base/src/util/cache_provider_base.dart';
import 'package:test/test.dart';
import 'package:path/path.dart';

import 'dart:convert';
import 'dart:io';

void main() {
  test('MemoryCache should works well', () async {
    final memoryCache = CacheProvider.createInMemoryCache<_MockCacheValue>(
        Duration(seconds: 1));
    final value = _MockCacheValue(1);

    {
      final (cacheValue, getResult) =
          await memoryCache.get('key_1', () async => value);
      expect(cacheValue!.value, 1);
      expect(getResult, GetResult.fromFallback);
    }

    {
      final (cacheValue, getResult) = await memoryCache.get(
          'key_1', () async => fail('expected to get cache, but not'));
      expect(cacheValue!.value, 1);
      expect(getResult, GetResult.fromCache);
    }

    value.valid = false;

    {
      final (cacheValue, getResult) = await memoryCache.get(
          'key_1', () async => throw Exception('test error'));
      expect(cacheValue!.value, 1);
      expect(getResult, GetResult.fromInvalidCache);
    }

    await Future.delayed(Duration(seconds: 1));

    {
      final (cacheValue, getResult) = await memoryCache.get(
          'key_1', () async => throw Exception('test error'));
      expect(cacheValue!.value, 1);
      expect(getResult, GetResult.fromInvalidCache);
    }

    await Future.delayed(Duration(seconds: 1));

    {
      final (cacheValue, getResult) = await memoryCache.get(
          'key_1', () async => throw Exception('test error'));
      expect(cacheValue, null);
      expect(getResult, GetResult.none);
    }

    {
      final (cacheValue, getResult) =
          await memoryCache.get('key_1', () async => _MockCacheValue(2));
      expect(cacheValue!.value, 2);
      expect(getResult, GetResult.fromFallback);
    }

    {
      final (cacheValue, getResult) = await memoryCache.get(
          'key_1', () async => fail('expected to get cache, but not'));
      expect(cacheValue!.value, 2);
      expect(getResult, GetResult.fromCache);
    }
  });

  test('PersistentCache should works well', () async {
    final tmpDir = await Directory.systemTemp.createTemp();
    try {
      final persistentCache =
          await CacheProvider.createPersistentCache<_MockCacheValue>(
              join(tmpDir.path, 'cache'),
              Duration(seconds: 1),
              Duration(seconds: 1),
              (pair) => _MockCacheValue._serialize(pair),
              (line) => _MockCacheValue._deserialize(line), (error, stack) {
        fail('should not catch an error: $error, stack: $stack');
      });
      final value = _MockCacheValue(1);
      {
        final (cacheValue, getResult) =
            await persistentCache.get('key_1', () async => value);
        expect(cacheValue!.value, 1);
        expect(getResult, GetResult.fromFallback);
      }
      {
        final (cacheValue, getResult) = await persistentCache.get(
            'key_1', () async => fail('expected to get cache, but not'));
        expect(cacheValue!.value, 1);
        expect(getResult, GetResult.fromCache);
      }

      await Future.delayed(Duration(seconds: 1));

      {
        final (cacheValue, getResult) = await persistentCache.get(
            'key_1', () async => fail('expected to get cache, but not'));
        expect(cacheValue!.value, 1);
        expect(getResult, GetResult.fromCache);
      }

      await Future.delayed(Duration(seconds: 1));

      {
        final persistentCache2 =
            await CacheProvider.createPersistentCache<_MockCacheValue>(
                join(tmpDir.path, 'cache'),
                Duration(seconds: 2),
                Duration(seconds: 1),
                (pair) => _MockCacheValue._serialize(pair),
                (line) => _MockCacheValue._deserialize(line), (error, stack) {
          fail('should not catch an error: $error, stack: $stack');
        });

        {
          final (cacheValue, getResult) = await persistentCache2.get(
              'key_1', () async => fail('expected to get cache, but not'));
          expect(cacheValue!.value, 1);
          expect(getResult, GetResult.fromCache);
        }
      }

      value.refresh = true;
      final value2 = _MockCacheValue(2);

      {
        final (cacheValue, getResult) =
            await persistentCache.get('key_1', () async => value2);
        expect(cacheValue!.value, 1);
        expect(getResult, GetResult.fromCacheAndRefreshAsync);
      }

      await Future.delayed(Duration(seconds: 1));

      {
        final (cacheValue, getResult) = await persistentCache.get(
            'key_1', () async => fail('expected to get cache, but not'));
        expect(cacheValue!.value, 2);
        expect(getResult, GetResult.fromCache);
      }

      value2.valid = false;

      {
        final (cacheValue, getResult) = await persistentCache.get(
            'key_1', () async => throw Exception('test exception'));
        expect(cacheValue, null);
        expect(getResult, GetResult.none);
      }

      await persistentCache.clear();
      await Future.delayed(Duration(seconds: 1));
    } finally {
      await tmpDir.delete(recursive: true);
    }
  });
}

final class _MockCacheValue extends CacheValue {
  int value;
  bool valid;
  bool refresh;

  _MockCacheValue(this.value, {this.valid = true, this.refresh = false});

  @override
  bool isValid() {
    return valid;
  }

  @override
  bool shouldRefresh() {
    return refresh;
  }

  static CachePair<_MockCacheValue> _deserialize(String line) {
    final map = jsonDecode(
      line,
      reviver: (key, value) {
        if (key == 'k') {
          return value;
        } else if (key == 'v') {
          return value;
        } else if (key == 'd') {
          return value;
        } else if (key == 'r') {
          return value;
        } else if (key == 'c') {
          return DateTime.parse(value as String);
        } else {
          return value;
        }
      },
    );
    return CachePair(
      map['k'],
      _MockCacheValue(map['v'], valid: map['d'], refresh: map['r']),
      map['c'],
    );
  }

  static String _serialize(CachePair<_MockCacheValue> pair) {
    return jsonEncode(pair, toEncodable: (object) {
      if (object is CachePair<_MockCacheValue>) {
        return {
          'k': object.key,
          'v': object.data.value,
          'd': object.data.valid,
          'r': object.data.refresh,
          'c': object.createdAt.toIso8601String(),
        };
      } else {
        fail('unexpected object type: $object');
      }
    });
  }
}
