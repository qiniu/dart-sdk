import 'dart:io';

import 'package:dotenv/dotenv.dart' show load, clean, isEveryDefined, env;
import 'package:qiniu_sdk_base/src/auth/auth.dart';
import 'package:test/test.dart';

String token;

bool get isSensitiveDataDefined {
  load();
  return isEveryDefined([
    'QINIU_DART_SDK_ACCESS_KEY',
    'QINIU_DART_SDK_SECRET_KEY',
    'QINIU_DART_SDK_TOKEN_SCOPE'
  ]);
}

void configEnv() {
  setUpAll(() {
    if (isSensitiveDataDefined) {
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
    } else {
      stderr.writeln('没有在 .env 文件里配置测试用的必要信息，一些测试用例会被跳过');
    }
  });

  tearDownAll(clean);
}
