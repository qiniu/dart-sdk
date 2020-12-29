import 'package:qiniu_sdk_base/src/storage/storage.dart';
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';
import 'package:test/test.dart';

import '../config.dart';

void main() {
  configEnv();
  test('put controller basic.', () async {
    final controller = PutController();
    expect(controller.isCancelled, false);
    controller.cancel();
    expect(controller.isCancelled, true);
    controller.cancel();
    expect(controller.isCancelled, true);
  }, skip: !isSensitiveDataDefined);
}
