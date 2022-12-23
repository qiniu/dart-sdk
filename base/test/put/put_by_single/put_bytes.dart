@Timeout(Duration(seconds: 60))
import 'package:dotenv/dotenv.dart' show env;
import 'package:qiniu_sdk_base_diox/qiniu_sdk_base.dart';
import 'package:test/test.dart';

import '../../config.dart';
import '../helpers.dart';

void main() {
  configEnv();

  final storage = Storage();
  final bytes = fileForSingle.readAsBytesSync();

  test('customVars&returnBody should works well.', () async {
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

    var putController = PutController();
    final response = await storage.putBytes(
      bytes,
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
  }, skip: !isSensitiveDataDefined);

  test('putBytes should works well.', () async {
    var pcb = PutControllerBuilder();
    final response = await storage.putBytes(
      bytes,
      token,
      options: PutOptions(
        forceBySingle: true,
        key: fileKeyForSingle,
        controller: pcb.putController,
      ),
    );

    pcb.testAll();
    expect(response.key, fileKeyForSingle);
  }, skip: !isSensitiveDataDefined);

  test('putBytes can be cancelled.', () async {
    final putController = PutController();
    final key = fileKeyForSingle;

    final statusList = <StorageStatus>[];
    putController.addStatusListener((status) {
      statusList.add(status);
      if (status == StorageStatus.Request) {
        putController.cancel();
      }
    });
    var future = storage.putBytes(
      bytes,
      token,
      options:
          PutOptions(forceBySingle: true, key: key, controller: putController),
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
      await storage.putBytes(
        bytes,
        token,
        options: PutOptions(
            forceBySingle: true, key: key, controller: putController),
      );
    } catch (error) {
      // 复用了相同的 controller，所以也会触发取消的错误
      expect(error, isA<StorageError>());
      expect((error as StorageError).type, StorageErrorType.CANCEL);
    }

    expect(future, throwsA(TypeMatcher<StorageError>()));

    final response = await storage.putBytes(
      bytes,
      token,
      options: PutOptions(forceBySingle: true, key: key),
    );

    expect(response, isA<PutResponse>());
  }, skip: !isSensitiveDataDefined);

  test('putBytes\'s status and progress should works well.', () async {
    final pcb = PutControllerBuilder();

    final response = await storage.putBytes(
      bytes,
      token,
      options: PutOptions(
        forceBySingle: true,
        key: fileKeyForSingle,
        controller: pcb.putController,
      ),
    );
    expect(response.key, fileKeyForSingle);
    pcb.testAll();
  }, skip: !isSensitiveDataDefined);
}
