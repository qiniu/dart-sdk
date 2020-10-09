import 'dart:io';

import 'package:dotenv/dotenv.dart' show load, clean, isEveryDefined, env;
import 'package:qiniu_sdk_base/src/auth/auth.dart';
import 'package:test/test.dart';

String token;

void configEnv() {
  setUpAll(() {
    print(Platform.environment);
    load();
    if (!isEveryDefined([
      'QINIU_DART_SDK_ACCESS_KEY',
      'QINIU_DART_SDK_SECRET_KEY',
      'QINIU_DART_SDK_TOKEN_SCOPE'
    ])) {
      throw Exception('需要在 .env 文件里配置测试用的必要信息');
    }
    var auth = Auth(
      accessKey: env['QINIU_DART_SDK_ACCESS_KEY'],
      secretKey: env['QINIU_DART_SDK_SECRET_KEY'],
    );

    token = auth.generateUploadToken(
      putPolicy: PutPolicy(
          insertOnly: 0,
          scope: env['QINIU_DART_SDK_TOKEN_SCOPE'],
          deadline: DateTime.now().millisecondsSinceEpoch + 3600),
    );
  });

  tearDownAll(clean);
}
