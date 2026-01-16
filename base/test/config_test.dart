import 'dart:convert';
import 'dart:io';

import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';
import 'package:test/test.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

import 'config.dart';

void main() {
  configEnv();
  test(
    'RegionProvider should works well.',
    () async {
      final hostProvider = DefaultHostProviderV2();
      final token = generateUploadToken('test');
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

  test('BucketRegionsQuery should works well', () async {
    int count = 0;
    Future<Response> queryHandler(Request request) async {
      count += 1;
      expect(request.url.queryParameters['ak'], 'testak');
      expect(request.url.queryParameters['bucket'], 'testbucket');
      await Future.delayed(Duration(seconds: 1));
      return Response.ok(
        jsonEncode(
          {
            'hosts': [
              {
                'region': 'z0',
                'ttl': 86400,
                'io': {
                  'domains': [
                    'iovip.qbox.me',
                  ],
                },
                'io_src': {
                  'domains': [
                    'z0-bucket.kodo-cn-east-1.qiniucs.com',
                  ],
                },
                'up': {
                  'domains': [
                    'upload.qiniup.com',
                    'up.qiniup.com',
                    'upload-cn-east-1.qiniuio.com',
                  ],
                  'old': [
                    'upload.qbox.me',
                    'up.qbox.me',
                  ],
                  'acc_domains': [
                    'z0-bucket.kodo-accelerate.cn-east-1.qiniucs.com',
                  ],
                },
                'uc': {
                  'domains': ['uc.qbox.me'],
                },
                'rs': {
                  'domains': [
                    'rs-z0.qbox.me',
                  ],
                },
                'rsf': {
                  'domains': [
                    'rsf-z0.qbox.me',
                  ],
                },
                'api': {
                  'domains': [
                    'api.qiniu.com',
                  ],
                },
                's3': {
                  'domains': [
                    's3.cn-east-1.qiniucs.com',
                  ],
                  'region_alias': 'cn-east-1',
                },
              },
              {
                'region': 'z1',
                'ttl': 86400,
                'io': {
                  'domains': [
                    'iovip-z1.qbox.me',
                  ],
                },
                'io_src': {
                  'domains': [
                    'z0-bucket.kodo-cn-north-1.qiniucs.com',
                  ],
                },
                'up': {
                  'domains': [
                    'upload-z1.qiniup.com',
                    'up-z1.qiniup.com',
                    'upload-cn-north-1.qiniuio.com',
                  ],
                  'old': [
                    'upload-z1.qbox.me',
                    'up-z1.qbox.me',
                  ],
                  'acc_domains': [
                    'z0-bucket.kodo-accelerate.cn-east-1.qiniucs.com',
                  ],
                },
                'uc': {
                  'domains': [
                    'uc.qbox.me',
                  ],
                },
                'rs': {
                  'domains': [
                    'rs-z1.qbox.me',
                  ],
                },
                'rsf': {
                  'domains': [
                    'rsf-z1.qbox.me',
                  ],
                },
                'api': {
                  'domains': [
                    'api-z1.qiniu.com',
                  ],
                },
                's3': {
                  'domains': [
                    's3.cn-north-1.qiniucs.com',
                  ],
                  'region_alias': 'cn-north-1',
                },
              },
            ],
            'ttl': 86400,
          },
        ),
        headers: {
          'content-type': 'application/json',
          'x-reqid': 'fakeReqid',
        },
      );
    }

    final router = Router()..get('/v4/query', queryHandler);
    final app =
        const Pipeline().addMiddleware(logRequests()).addHandler(router.call);
    final server = await serve(
      app,
      InternetAddress.loopbackIPv4,
      0,
    );
    try {
      final query = await BucketRegionsQuery.create(
        bucketHosts: Endpoints(preferred: ['127.0.0.1:${server.port}']),
        useHttps: false,
      );
      final regionFutures = <Future<RegionsProvider>>[];
      for (int i = 0; i < 10; i++) {
        regionFutures
            .add(query.query(accessKey: 'testak', bucketName: 'testbucket'));
      }
      final regions = await Future.wait(regionFutures);
      for (final region in regions) {
        expect(region.regions.length, 2);
        expect(region.regions.first.up.accelerated, []);
        expect(region.regions.first.up.preferred, [
          'upload.qiniup.com',
          'up.qiniup.com',
          'upload-cn-east-1.qiniuio.com',
        ]);
        expect(
          region.regions.first.up.alternative,
          ['upload.qbox.me', 'up.qbox.me'],
        );
        expect(region.regions.first.bucket.accelerated, []);
        expect(region.regions.first.bucket.preferred, ['uc.qbox.me']);
        expect(region.regions.first.bucket.alternative, []);
      }
      expect(count, 1);

      final region = await query.query(
        accessKey: 'testak',
        bucketName: 'testbucket',
        accelerateUploading: true,
      );
      expect(region.regions.length, 2);
      expect(
        region.regions.first.up.accelerated,
        ['z0-bucket.kodo-accelerate.cn-east-1.qiniucs.com'],
      );
      expect(region.regions.first.up.preferred, [
        'upload.qiniup.com',
        'up.qiniup.com',
        'upload-cn-east-1.qiniuio.com',
      ]);
      expect(
        region.regions.first.up.alternative,
        ['upload.qbox.me', 'up.qbox.me'],
      );
      expect(region.regions.first.bucket.accelerated, []);
      expect(region.regions.first.bucket.preferred, ['uc.qbox.me']);
      expect(region.regions.first.bucket.alternative, []);
      expect(count, 2);
    } finally {
      server.close(force: true);
    }
  });
}
