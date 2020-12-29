import 'package:dotenv/dotenv.dart';
import 'package:qiniu_sdk_base/src/storage/storage.dart';
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';
import 'package:test/test.dart';

import 'config.dart';

void main() {
  configEnv();
  test('RegionProvider should works well.', () async {
    final hostProvider = DefaultHostProvider();
    final tokenInfo = Auth.parseUpToken(token);
    final putPolicy = tokenInfo.putPolicy;

    final hostInToken = await hostProvider.getUpHost(
      accessKey: tokenInfo.accessKey,
      bucket: putPolicy.getBucket(),
    );

    // 根据传入的 token 的 bucket 对应的区域，需要对应的修改这里
    expect(hostInToken, 'https://upload-z2.qiniup.com');
  }, skip: !isSensitiveDataDefined);

  test('DefaultCacheProvider should works well.', () async {
    final cacheProvider = DefaultCacheProvider();

    final cacheKey = 'init_parts';
    cacheProvider.setItem(cacheKey, 'anything');

    expect(cacheProvider.value.length, 1);
    expect(cacheProvider.getItem(cacheKey), 'anything');

    cacheProvider.removeItem(cacheKey);

    expect(cacheProvider.value.length, 0);
  });

  test('freeze mechanism should works well with DefaultHostProvider.',
      () async {
    final config = Config();
    final hostA = await config.hostProvider.getUpHost(
      accessKey: env['QINIU_DART_SDK_ACCESS_KEY'],
      bucket: env['QINIU_DART_SDK_TOKEN_SCOPE'],
    );
    config.hostProvider.freezeHost(hostA);
    final hostB = await config.hostProvider.getUpHost(
      accessKey: env['QINIU_DART_SDK_ACCESS_KEY'],
      bucket: env['QINIU_DART_SDK_TOKEN_SCOPE'],
    );

    // getUpHost 会返回至少2个host，不用担心会少于两个
    expect(hostA == hostB, false);
  }, skip: !isSensitiveDataDefined);
}
