import 'dart:io';
import 'package:qiniu_sdk_base/src/storage/methods/put/put_response.dart';
import 'package:test/test.dart';
import 'package:dotenv/dotenv.dart' show env;
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';

import '../config.dart';
import 'put_controller_builder.dart';

void main() {
  configEnv();

  final storage = Storage();

  test('put should works well.', () async {
    var pcb = PutControllerBuilder();
    final response = await storage.putFile(
      File('test_resource/test_for_put.txt'),
      token,
      options: PutOptions(
        key: 'test_for_put.txt',
        controller: pcb.putController,
      ),
    );
    pcb.testAll();
    expect(response.key, 'test_for_put.txt');

    // 分片
    pcb = PutControllerBuilder();
    final file = File('test_resource/test_for_put_parts.mp4');
    final putResponseByPart = await storage.putFile(
      file,
      token,
      options: PutOptions(
        key: 'test_for_put_parts.mp4',
        partSize: 1,
        controller: pcb.putController,
      ),
    );

    expect(putResponseByPart, isA<PutResponse>());

    pcb.testAll();
  }, skip: !isSensitiveDataDefined);

  test('put with returnBody should works well.', () async {
    final auth = Auth(
      accessKey: env['QINIU_DART_SDK_ACCESS_KEY'],
      secretKey: env['QINIU_DART_SDK_SECRET_KEY'],
    );

    final token = auth.generateUploadToken(
      putPolicy: PutPolicy(
        insertOnly: 0,
        returnBody: '{"ext": \$(ext)}',
        scope: env['QINIU_DART_SDK_TOKEN_SCOPE'],
        deadline: DateTime.now().millisecondsSinceEpoch + 3600,
      ),
    );

    final response = await storage.putFile(
      File('test_resource/test_for_put.txt'),
      token,
      options: PutOptions(key: 'test_for_put.txt'),
    );

    expect(response.rawData, {'ext': '.txt'});
  }, skip: !isSensitiveDataDefined);
}
