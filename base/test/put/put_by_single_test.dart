@Timeout(Duration(seconds: 60))

import 'dart:io';
import 'package:qiniu_sdk_base/src/storage/error/error.dart';
import 'package:qiniu_sdk_base/src/storage/methods/put/put_response.dart';
import 'package:test/test.dart';
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';
import 'package:dotenv/dotenv.dart' show env;

import '../config.dart';
import 'put_controller_builder.dart';

void main() {
  configEnv();

  final storage = Storage();

  test('putFileBySingle customVars should works well.', () async {
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

    var customVars = <String, String>{
      'x:type': 'testXType',
      'x:ext': 'testXExt',
    };

    final file = File('test_resource/test_for_put.txt');
    var putController = PutController();
    final response = await storage.putFileBySingle(
      file,
      token,
      options: PutBySingleOptions(
        key: 'test_for_put.txt',
        customVars: customVars,
        controller: putController,
      ),
    );

    expect(response.key, 'test_for_put.txt');
    expect(response.rawData['type'], 'testXType');
    expect(response.rawData['ext'], 'testXExt');
  }, skip: !isSensitiveDataDefined);

  test('putFileBySingle should works well.', () async {
    final file = File('test_resource/test_for_put.txt');
    var pcb = PutControllerBuilder();
    final response = await storage.putFileBySingle(
      file,
      token,
      options: PutBySingleOptions(
        key: 'test_for_put.txt',
        controller: pcb.putController,
      ),
    );

    pcb.testAll();
    expect(response.key, 'test_for_put.txt');
  }, skip: !isSensitiveDataDefined);

  test('putFileBySingle can be cancelled.', () async {
    final putController = PutController();
    final key = 'test_for_put.txt';
    final file = File('test_resource/test_for_put.txt');

    final statusList = <StorageStatus>[];
    putController.addStatusListener((status) {
      statusList.add(status);
      if (status == StorageStatus.Request) {
        putController.cancel();
      }
    });
    var future = storage.putFileBySingle(
      file,
      token,
      options: PutBySingleOptions(key: key, controller: putController),
    );
    try {
      await future;
    } catch (error) {
      expect(error, isA<StorageError>());
      expect((error as StorageError).type, StorageErrorType.CANCEL);
    }
    expect(future, throwsA(TypeMatcher<StorageError>()));
    expect(statusList[0], StorageStatus.Init);
    expect(statusList[1], StorageStatus.Request);
    expect(statusList[2], StorageStatus.Cancel);

    try {
      await storage.putFileBySingle(
        file,
        token,
        options: PutBySingleOptions(key: key, controller: putController),
      );
    } catch (error) {
      // 复用了相同的 controller，所以也会触发取消的错误
      expect(error, isA<StorageError>());
      expect((error as StorageError).type, StorageErrorType.CANCEL);
    }

    expect(future, throwsA(TypeMatcher<StorageError>()));

    final response = await storage.putFileBySingle(
      file,
      token,
      options: PutBySingleOptions(key: key),
    );

    expect(response, isA<PutResponse>());
  }, skip: !isSensitiveDataDefined);

  test('putFileBySingle\'s status and progress should works well.', () async {
    final pcb = PutControllerBuilder();

    final response = await storage.putFileBySingle(
      File('test_resource/test_for_put.txt'),
      token,
      options: PutBySingleOptions(
        key: 'test_for_put.txt',
        controller: pcb.putController,
      ),
    );
    expect(response.key, 'test_for_put.txt');
    pcb.testAll();
  }, skip: !isSensitiveDataDefined);
}
