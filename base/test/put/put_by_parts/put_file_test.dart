@Timeout(Duration(seconds: 60))

import 'dart:convert';
import 'dart:io';

import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';
import 'package:qiniu_sdk_base/src/storage/methods/put/by_part/put_parts_task.dart';
import 'package:qiniu_sdk_base/src/storage/resource/resource.dart';
import 'package:test/test.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;

import '../../config.dart';
import '../helpers.dart';

void main() {
  configEnv();

  test(
    'customVars&returnBody should works well.',
    () async {
      final storage = Storage();

      final auth = Auth(
        accessKey: env['QINIU_DART_SDK_ACCESS_KEY']!,
        secretKey: env['QINIU_DART_SDK_SECRET_KEY']!,
      );

      final token = auth.generateUploadToken(
        putPolicy: PutPolicy(
          insertOnly: 0,
          scope: env['QINIU_DART_SDK_TOKEN_SCOPE']!,
          returnBody: '{"key":"\$(key)","type":"\$(x:type)","ext":"\$(x:ext)"}',
          deadline: DateTime.now().millisecondsSinceEpoch + 3600,
        ),
      );

      final customVars = <String, String>{
        'x:type': 'testXType',
        'x:ext': 'testXExt',
      };

      final putController = PutController();
      final response = await storage.putFile(
        fileForPart,
        token,
        options: PutOptions(
          key: fileKeyForPart,
          partSize: 1,
          customVars: customVars,
          controller: putController,
        ),
      );

      expect(response.key, fileKeyForPart);
      expect(response.rawData['type'], 'testXType');
      expect(response.rawData['ext'], 'testXExt');
    },
    skip: !isSensitiveDataDefined,
  );

  test(
    'putFile should works well.',
    () async {
      final storage = Storage();
      final pcb = PutControllerBuilder();
      var callnumber = 0;
      pcb.putController.addSendProgressListener((percent) {
        callnumber++;
      });
      final response = await storage.putFile(
        fileForPart,
        token,
        options: PutOptions(
          key: fileKeyForPart,
          partSize: 1,
          controller: pcb.putController,
        ),
      );
      expect(response, isA<PutResponse>());
      // 2 片分片所以 2 次
      expect(callnumber, 2);

      pcb.testAll();

      // 不设置参数的情况
      final responseNoOps = await storage.putFile(
        fileForPart,
        token,
      );

      expect(responseNoOps, isA<PutResponse>());
    },
    skip: !isSensitiveDataDefined,
  );

  test(
    'putFile should throw error with incorrect partSize.',
    () async {
      final storage = Storage();
      try {
        await storage.putFile(
          fileForPart,
          token,
          options: PutOptions(partSize: 0),
        );
      } catch (e) {
        expect(e, isA<AssertionError>());
      }

      try {
        await storage.putFile(
          fileForPart,
          token,
          options: PutOptions(partSize: 1025),
        );
      } catch (e) {
        expect(e, isA<AssertionError>());
      }
    },
    skip: !isSensitiveDataDefined,
  );

  test(
    'putFile should works well while response 612.',
    () async {
      final httpAdapterTest = HttpAdapterTestWith612();
      final storage =
          Storage(config: Config(httpClientAdapter: httpAdapterTest));
      final response = await storage.putFile(
        fileForPart,
        token,
        options: PutOptions(key: fileKeyForPart, partSize: 1),
      );

      /// httpAdapterTest 应该会触发一次 612 response
      expect(httpAdapterTest.completePartsTaskResponse612, true);
      expect(response, isA<PutResponse>());
    },
    skip: !isSensitiveDataDefined,
  );

  test(
    'putFile can be cancelled.',
    () async {
      final pcb = PutControllerBuilder();
      final storage = Storage(config: Config(hostProvider: HostProviderTest()));
      final key = fileKeyForPart;
      pcb.putController.addSendProgressListener((percent) {
        // 开始上传并且 InitPartsTask 设置完缓存后取消
        if (percent > 0.1) {
          pcb.putController.cancel();
        }
      });
      final future = storage.putFile(
        fileForPart,
        token,
        options: PutOptions(
          key: key,
          partSize: 1,
          controller: pcb.putController,
        ),
      );
      try {
        await future;
      } catch (error) {
        expect((error as StorageError).type, StorageErrorType.CANCEL);
      }
      expect(future, throwsA(TypeMatcher<StorageError>()));
      pcb.testStatus(
        targetStatusList: [
          StorageStatus.Init,
          StorageStatus.Request,
          StorageStatus.Cancel,
        ],
        targetProgressList: [
          0.001,
          0.002,
        ],
      );

      try {
        await storage.putFile(
          fileForPart,
          token,
          options: PutOptions(
            key: key,
            partSize: 1,
            controller: pcb.putController,
          ),
        );
      } catch (error) {
        // 复用了相同的 controller，所以也会触发取消的错误
        expect(error, isA<StorageError>());
        expect((error as StorageError).type, StorageErrorType.CANCEL);
      }

      expect(future, throwsA(isA<StorageError>()));

      final response = await storage.putFile(
        fileForPart,
        token,
        options: PutOptions(key: key, partSize: 1),
      );
      expect(response, isA<PutResponse>());
    },
    skip: !isSensitiveDataDefined,
  );

  test(
    'putFile can be resumed.',
    () async {
      final storage = Storage(config: Config(hostProvider: HostProviderTest()));
      final putController = PutController();
      putController.addSendProgressListener((percent) {
        // 开始上传了取消
        if (percent > 0.1) {
          putController.cancel();
        }
      });

      final future = storage.putFile(
        fileForPart,
        token,
        options: PutOptions(
          key: fileKeyForPart,
          partSize: 1,
          controller: putController,
        ),
      );

      try {
        await future;
      } catch (error) {
        expect(error, isA<StorageError>());
        expect((error as StorageError).type, StorageErrorType.CANCEL);
      }

      expect(future, throwsA(TypeMatcher<StorageError>()));

      final response = await storage.putFile(
        fileForPart,
        token,
        options: PutOptions(key: fileKeyForPart, partSize: 1),
      );

      expect(response, isA<PutResponse>());
    },
    skip: !isSensitiveDataDefined,
  );

  test(
    'putFile should works well with cacheProvider.',
    () async {
      final cacheProvider = CacheProviderForTest();
      final config = Config(cacheProvider: cacheProvider);
      final storage = Storage(config: config);
      final key = fileKeyForPart;
      final resource =
          FileResource(file: fileForPart, length: fileForPart.lengthSync());

      /// 手动初始化一个初始化文件的任务，确定分片上传的第一步会被缓存
      final task = InitPartsTask(
        token: token,
        resource: resource,
        key: key,
      );

      storage.taskManager.addTask(task);

      await task.future;

      final putController = PutController();

      putController.addSendProgressListener((percent) {
        // 因为一共 2 个分片，取 0.5 一个完成后就取消
        if (percent > 0.5) {
          putController.cancel();
        }
      });

      final future = storage.putFile(
        fileForPart,
        token,
        options: PutOptions(key: key, partSize: 1, controller: putController),
      );

      /// 这个时候应该只缓存了初始化的缓存信息
      expect(cacheProvider.value.length, 1);

      /// 初始化的缓存 key 生成逻辑
      final cacheKey = InitPartsTask.getCacheKey(
        resource.id,
        key,
      );

      expect(await cacheProvider.getItem(cacheKey), isA<String>());
      await cacheProvider.clear();

      try {
        await future;
      } catch (error) {
        expect(error, isA<StorageError>());
        expect((error as StorageError).type, StorageErrorType.CANCEL);
        // 每个分片完成后会保存一次
        // init 一次，仅有的一个分片完成后一次共 2 次
        expect(cacheProvider.callNumber, 2);
      }

      await cacheProvider.clear();
      cacheProvider.callNumber = 0;

      final response = await storage.putFile(
        fileForPart,
        token,
        options: PutOptions(key: key, partSize: 1),
      );

      expect(response, isA<PutResponse>());

      /// 上传完成后缓存应该被清理
      expect(cacheProvider.value.length, 0);
      // init + 2 个分片 2 次 = 3 次
      expect(cacheProvider.callNumber, 3);
    },
    skip: !isSensitiveDataDefined,
  );

  test(
    'putFile should throw error if there is a same task is working.',
    () async {
      final storage = Storage();
      final key = fileKeyForPart;

      var errorOccurred = false;

      // 故意不 await，让后面发送一个相同的任务
      // ignore: unawaited_futures
      storage.putFile(
        fileForPart,
        token,
        options: PutOptions(
          key: key,
          partSize: 1,
        ),
      );

      try {
        await storage.putFile(
          fileForPart,
          token,
          options: PutOptions(
            key: key,
            partSize: 1,
          ),
        );
      } catch (e) {
        errorOccurred = true;
        expect(e, isA<StorageError>());
        expect((e as StorageError).type, StorageErrorType.IN_PROGRESS);
      }
      expect(errorOccurred, true);
    },
    skip: !isSensitiveDataDefined,
  );

  test(
    'putFile\'s status and progress should works well.',
    () async {
      final storage = Storage();
      final pcb = PutControllerBuilder();

      final response = await storage.putFile(
        fileForPart,
        token,
        options: PutOptions(
          key: fileKeyForPart,
          partSize: 1,
          controller: pcb.putController,
        ),
      );
      expect(response, isA<PutResponse>());
      pcb
        ..testProcess()
        ..testStatus(targetProgressList: [0.001, 0.002, 0.99, 1]);
    },
    skip: !isSensitiveDataDefined,
  );

  test('putFile should try another region', () async {
    final bucket = env['QINIU_DART_SDK_TOKEN_SCOPE']!;
    int upload1InitPartsCalled = 0;
    int upload1UploadPartCalled = 0;
    Future<shelf.Response> upload1InitPartsHandler(
      shelf.Request request,
    ) async {
      upload1InitPartsCalled += 1;
      return shelf.Response(
        200,
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'uploadId': 'testUploadId',
          'expireAt': (DateTime.now().millisecondsSinceEpoch / 1000).ceil(),
        }),
      );
    }

    Future<shelf.Response> upload1UploadPartHandler(
      shelf.Request request,
    ) async {
      upload1UploadPartCalled += 1;
      return shelf.Response(
        599,
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'error': 'test error'}),
      );
    }

    final up1Router = shelf_router.Router()
      ..post(
        '/buckets/$bucket/objects/${base64UrlEncode(utf8.encode(fileKeyForPart))}/uploads',
        upload1InitPartsHandler,
      )
      ..put(
        '/buckets/$bucket/objects/${base64UrlEncode(utf8.encode(fileKeyForPart))}/uploads/testUploadId/<partNumber>',
        upload1UploadPartHandler,
      );
    final up1App = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(up1Router.call);
    final up1Server = await shelf_io.serve(
      up1App,
      InternetAddress.loopbackIPv4,
      0,
    );

    int upload2InitPartsCalled = 0;
    int upload2UploadPartCalled = 0;
    int upload2CompletePartsCalled = 0;
    Future<shelf.Response> upload2InitPartsHandler(
      shelf.Request request,
    ) async {
      upload2InitPartsCalled += 1;
      return shelf.Response(
        200,
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'uploadId': 'testUploadId2',
          'expireAt': (DateTime.now().millisecondsSinceEpoch / 1000).ceil(),
        }),
      );
    }

    Future<shelf.Response> upload2UploadPartHandler(
      shelf.Request request,
    ) async {
      upload2UploadPartCalled += 1;
      return shelf.Response(
        200,
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'etag': 'fakeEtag$upload2UploadPartCalled',
          'md5': 'fakeMd5$upload2UploadPartCalled',
        }),
      );
    }

    Future<shelf.Response> upload2CompletePartsHandler(
      shelf.Request request,
    ) async {
      upload2CompletePartsCalled += 1;
      return shelf.Response(
        200,
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'key': fileKeyForPart}),
      );
    }

    final up2Router = shelf_router.Router()
      ..post(
        '/buckets/$bucket/objects/${base64UrlEncode(utf8.encode(fileKeyForPart))}/uploads',
        upload2InitPartsHandler,
      )
      ..put(
        '/buckets/$bucket/objects/${base64UrlEncode(utf8.encode(fileKeyForPart))}/uploads/testUploadId2/<partNumber>',
        upload2UploadPartHandler,
      )
      ..post(
        '/buckets/$bucket/objects/${base64UrlEncode(utf8.encode(fileKeyForPart))}/uploads/testUploadId2',
        upload2CompletePartsHandler,
      );
    final up2App = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(up2Router.call);
    final up2Server = await shelf_io.serve(
      up2App,
      InternetAddress.loopbackIPv4,
      0,
    );

    Future<shelf.Response> queryHandler(shelf.Request request) async {
      return shelf.Response.ok(
        jsonEncode(
          {
            'hosts': [
              {
                'region': 'z1',
                'ttl': 86400,
                'up': {
                  'domains': [
                    '127.0.0.1:${up1Server.port}',
                  ],
                },
              },
              {
                'region': 'z2',
                'ttl': 86400,
                'up': {
                  'domains': [
                    '127.0.0.1:${up2Server.port}',
                  ],
                },
              },
            ],
            'ttl': 86400,
          },
        ),
        headers: {
          'content-type': 'application/json',
        },
      );
    }

    final ucRouter = shelf_router.Router()..get('/v4/query', queryHandler);
    final ucApp = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(ucRouter.call);
    final ucServer = await shelf_io.serve(
      ucApp,
      InternetAddress.loopbackIPv4,
      0,
    );
    try {
      final storage = Storage(
        config: Config(
          hostProvider: DefaultHostProviderV2.from(
            bucketHosts: Endpoints(preferred: ['127.0.0.1:${ucServer.port}']),
            useHttps: false,
          ),
        ),
      );
      final response = await storage.putFile(
        fileForPart,
        token,
        options: PutOptions(
          key: fileKeyForPart,
          partSize: 1,
        ),
      );
      expect(response.key, fileKeyForPart);
      expect(upload1InitPartsCalled, 1);
      expect(upload1UploadPartCalled, 2);
      expect(upload2InitPartsCalled, 1);
      expect(upload2UploadPartCalled, 2);
      expect(upload2CompletePartsCalled, 1);
    } finally {
      ucServer.close(force: true);
      up1Server.close(force: true);
      up2Server.close(force: true);
    }
  });
}
