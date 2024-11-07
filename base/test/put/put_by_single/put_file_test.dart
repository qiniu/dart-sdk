@Timeout(Duration(seconds: 60))

import 'dart:convert';
import 'dart:io';

import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';
import 'package:test/test.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;

import '../../config.dart';
import '../helpers.dart';

void main() {
  configEnv();

  final storage = Storage();

  test(
    'putFile customVars should works well.',
    () async {
      final token = generateUploadToken(
        fileKeyForSingle,
        putPolicy: PutPolicy(
          insertOnly: 0,
          scope: "${env['QINIU_DART_SDK_TOKEN_SCOPE']!}:$fileKeyForSingle",
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
        fileForSingle,
        token,
        options: PutOptions(
          forceBySingle: true,
          key: fileKeyForSingle,
          customVars: customVars,
          controller: putController,
        ),
      );

      expect(response.key, fileKeyForSingle);
      expect(response.rawData['type'], 'testXType');
      expect(response.rawData['ext'], 'testXExt');
    },
    skip: !isSensitiveDataDefined,
  );

  test(
    'putFile should works well.',
    () async {
      final pcb = PutControllerBuilder();
      final token = generateUploadToken(fileKeyForSingle);
      final response = await storage.putFile(
        fileForSingle,
        token,
        options: PutOptions(
          forceBySingle: true,
          key: fileKeyForSingle,
          controller: pcb.putController,
        ),
      );

      pcb.testAll();
      expect(response.key, fileKeyForSingle);
    },
    skip: !isSensitiveDataDefined,
  );

  test(
    'putFile can be cancelled.',
    () async {
      final key = fileKeyForSingle;
      final token = generateUploadToken(key);

      {
        final (putController, statusList) = newCancelledPutController();
        final future = storage.putFile(
          fileForSingle,
          token,
          options: PutOptions(
            forceBySingle: true,
            key: key,
            controller: putController,
          ),
        );
        try {
          await future;
          fail('expected to throw StorageError');
        } on StorageError catch (error) {
          expect(error.type, StorageErrorType.CANCEL);
        }
        expect(future, throwsA(TypeMatcher<StorageError>()));
        expect(statusList[0], StorageStatus.Init);
        expect(statusList[1], StorageStatus.Request);
        expect(statusList[2], StorageStatus.Cancel);
      }

      {
        final (putController, statusList) = newCancelledPutController();
        try {
          await storage.putFile(
            fileForSingle,
            token,
            options: PutOptions(
              forceBySingle: true,
              key: key,
              controller: putController,
            ),
          );
          fail('expected to throw StorageError');
        } on StorageError catch (error) {
          // 复用了相同的 controller，所以也会触发取消的错误
          expect(error.type, StorageErrorType.CANCEL);
        }
        expect(statusList[0], StorageStatus.Init);
        expect(statusList[1], StorageStatus.Request);
        expect(statusList[2], StorageStatus.Cancel);
      }

      final response = await storage.putFile(
        fileForSingle,
        token,
        options: PutOptions(forceBySingle: true, key: key),
      );

      expect(response, isA<PutResponse>());
    },
    skip: !isSensitiveDataDefined,
  );

  test(
    'putFile\'s status and progress should works well.',
    () async {
      final pcb = PutControllerBuilder();
      final token = generateUploadToken(fileKeyForSingle);

      final response = await storage.putFile(
        fileForSingle,
        token,
        options: PutOptions(
          forceBySingle: true,
          key: fileKeyForSingle,
          controller: pcb.putController,
        ),
      );
      expect(response.key, fileKeyForSingle);
      pcb.testAll();
    },
    skip: !isSensitiveDataDefined,
  );

  test('putFile should try another region', () async {
    int upload1Called = 0;
    Future<shelf.Response> upload1Handler(shelf.Request request) async {
      upload1Called += 1;
      return shelf.Response(
        599,
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'error': 'fakeError'}),
      );
    }

    final up1Router = shelf_router.Router()..post('/', upload1Handler);
    final up1App = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(up1Router.call);
    final up1Server = await shelf_io.serve(
      up1App,
      InternetAddress.loopbackIPv4,
      0,
    );

    int upload2Called = 0;
    Future<shelf.Response> upload2Handler(shelf.Request request) async {
      upload2Called += 1;
      return shelf.Response(
        200,
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'key': fileKeyForSingle}),
      );
    }

    final up2Router = shelf_router.Router()..post('/', upload2Handler);
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
      final pcb = PutControllerBuilder();
      final token = generateUploadToken(fileKeyForSingle);
      final response = await storage.putFile(
        fileForSingle,
        token,
        options: PutOptions(
          forceBySingle: true,
          key: fileKeyForSingle,
          controller: pcb.putController,
        ),
      );
      expect(response.key, fileKeyForSingle);
      expect(upload1Called, 1);
      expect(upload2Called, 1);
    } finally {
      ucServer.close(force: true);
      up1Server.close(force: true);
      up2Server.close(force: true);
    }
  });
}
