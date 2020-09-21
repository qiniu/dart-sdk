import 'dart:io';

import 'package:test/test.dart';

import 'package:qiniu_sdk_base/src/storage.dart';

import 'token.dart';

void main() {
  final storage = Storage(token: token);

  test('put should works well.', () async {
    final putTask = storage.put(File(Directory.current.path + '/test/test.txt'),
        options: PutOptions(key: 'test.txt'));
    try {
      final response = await putTask.request;
      expect(response.data['key'], 'test.txt');
    } catch (err) {
      print(err.response);
    }
  });

  test('put can be canceled.', () async {
    final putTask = await storage.put(
        File(Directory.current.path + '/test/test.txt'),
        options: PutOptions(key: 'test.txt'));

    putTask.cancel();
  });
}
