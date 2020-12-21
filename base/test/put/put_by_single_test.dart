import 'dart:io';
import 'package:qiniu_sdk_base/src/storage/error/error.dart';
import 'package:qiniu_sdk_base/src/storage/methods/put/put_response.dart';
import 'package:test/test.dart';
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';

import '../config.dart';
import 'put_controller_builder.dart';

void main() {
  configEnv();

  final storage = Storage();

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

    final statusList = <RequestTaskStatus>[];
    putController.addStatusListener((status) {
      statusList.add(status);
      if (status == RequestTaskStatus.Request) {
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
    expect(statusList[0], RequestTaskStatus.Init);
    expect(statusList[1], RequestTaskStatus.Request);
    expect(statusList[2], RequestTaskStatus.Cancel);

    try {
      // 预期同步发生
      // ignore: unawaited_futures
      storage.putFileBySingle(
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
