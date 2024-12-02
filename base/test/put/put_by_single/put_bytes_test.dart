@Timeout(Duration(seconds: 60))
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';
import 'package:test/test.dart';

import '../../config.dart';
import '../helpers.dart';

void main() {
  configEnv();

  final storage = Storage();
  final bytes = fileForSingle.readAsBytesSync();

  test(
    'customVars&returnBody should works well.',
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
    },
    skip: !isSensitiveDataDefined,
  );

  test(
    'putBytes should works well.',
    () async {
      final pcb = PutControllerBuilder();
      final token = generateUploadToken(fileKeyForSingle);
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
    },
    skip: !isSensitiveDataDefined,
  );

  test(
    'putBytes can be cancelled.',
    () async {
      final key = fileKeyForSingle;
      final token = generateUploadToken(key);

      {
        final (putController, statusList) = newCancelledPutController();
        final future = storage.putBytes(
          bytes,
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
          await storage.putBytes(
            bytes,
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

      final response = await storage.putBytes(
        bytes,
        token,
        options: PutOptions(forceBySingle: true, key: key),
      );

      expect(response, isA<PutResponse>());
    },
    skip: !isSensitiveDataDefined,
  );

  test(
    'putBytes\'s status and progress should works well.',
    () async {
      final pcb = PutControllerBuilder();
      final token = generateUploadToken(fileKeyForSingle);

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
    },
    skip: !isSensitiveDataDefined,
  );
}
