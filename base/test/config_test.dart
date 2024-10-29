import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';
import 'package:test/test.dart';

import 'config.dart';

void main() {
  configEnv();
  test(
    'RegionProvider should works well.',
    () async {
      final hostProvider = DefaultHostProvider();
      final tokenInfo = Auth.parseUpToken(token);
      final putPolicy = tokenInfo.putPolicy;

      final hostInToken = await hostProvider.getUpHost(
        accessKey: tokenInfo.accessKey,
        bucket: putPolicy.getBucket(),
      );

      // 根据传入的 token 的 bucket 对应的区域，需要对应的修改这里
      expect(hostInToken, 'https://upload-na0.qiniup.com');
    },
    skip: !isSensitiveDataDefined,
  );

  test('DefaultCacheProvider should works well.', () async {
    final cacheProvider = DefaultCacheProvider();

    final cacheKey = 'init_parts';
    await cacheProvider.setItem(cacheKey, 'anything');

    expect(cacheProvider.value.length, 1);
    expect(await cacheProvider.getItem(cacheKey), 'anything');

    await cacheProvider.removeItem(cacheKey);

    expect(cacheProvider.value.length, 0);
  });

  test(
    'freeze mechanism should works well with DefaultHostProvider.',
    () async {
      final config = Config();
      final hostA = await config.hostProvider.getUpHost(
        accessKey: env['QINIU_DART_SDK_ACCESS_KEY']!,
        bucket: env['QINIU_DART_SDK_TOKEN_SCOPE']!,
      );
      config.hostProvider.freezeHost(hostA);
      final hostB = await config.hostProvider.getUpHost(
        accessKey: env['QINIU_DART_SDK_ACCESS_KEY']!,
        bucket: env['QINIU_DART_SDK_TOKEN_SCOPE']!,
      );

      // getUpHost 会返回至少2个host，不用担心会少于两个
      expect(hostA == hostB, false);
    },
    skip: !isSensitiveDataDefined,
  );

  test('Region should works well', () async {
    final region = Region.getByID('z0');
    expect(region.bucket.toList(), [
      'https://uc.qiniuapi.com',
      'https://kodo-config.qiniuapi.com',
      'https://uc.qbox.me',
    ]);
    expect(region.up.toList(), [
      'https://upload-z0.qiniup.com',
      'https://up-z0.qiniup.com',
    ]);
  });

  test('Endpoints should works well', () async {
    var endpoint = Endpoints(
      accelerated: ['domain1'],
      preferred: ['domain2', 'domain3'],
      alternative: ['domain4'],
    );
    expect(endpoint.length, 4);
    expect(endpoint.first, 'domain1');
    expect(endpoint.last, 'domain4');
    expect(endpoint.toList(), ['domain1', 'domain2', 'domain3', 'domain4']);
    expect(endpoint.isEmpty, false);
    expect(endpoint.isNotEmpty, true);

    endpoint = Endpoints(
      preferred: ['domain1', 'domain2'],
      alternative: ['domain3'],
    );
    expect(endpoint.length, 3);
    expect(endpoint.first, 'domain1');
    expect(endpoint.last, 'domain3');
    expect(endpoint.toList(), ['domain1', 'domain2', 'domain3']);
    expect(endpoint.isEmpty, false);
    expect(endpoint.isNotEmpty, true);

    endpoint = Endpoints(
      accelerated: ['domain1'],
      preferred: ['domain2', 'domain3'],
    );
    expect(endpoint.length, 3);
    expect(endpoint.first, 'domain1');
    expect(endpoint.last, 'domain3');
    expect(endpoint.toList(), ['domain1', 'domain2', 'domain3']);
    expect(endpoint.isEmpty, false);
    expect(endpoint.isNotEmpty, true);

    endpoint = Endpoints(
      preferred: ['domain1', 'domain2'],
    );
    expect(endpoint.length, 2);
    expect(endpoint.first, 'domain1');
    expect(endpoint.last, 'domain2');
    expect(endpoint.toList(), ['domain1', 'domain2']);
    expect(endpoint.isEmpty, false);
    expect(endpoint.isNotEmpty, true);
  });
}
