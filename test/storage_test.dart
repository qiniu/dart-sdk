import 'dart:io';

import 'package:dio/dio.dart';
import 'package:qiniu_sdk_base/src/config/config.dart';
import 'package:qiniu_sdk_base/src/task/put_parts_task.dart';
import 'package:qiniu_sdk_base/src/storage.dart';

@Timeout(Duration(seconds: 60))
import 'package:test/test.dart';

import 'config.dart';

void main() {
  configEnv();

  Storage storage;
  setUpAll(() {
    storage = Storage(token: token);
  });

  test('put should works well.', () async {
    final putTask = storage.put(File('test_resource/test_for_put.txt'),
        options: PutOptions(key: 'test_for_put.txt'));
    try {
      final response = await putTask.toFuture();
      expect(response.key, 'test_for_put.txt');
    } catch (err) {
      print(err);
    }
  });

  test('put can be canceled.', () async {
    final putTask = storage.put(File('test_resource/test_for_put.txt'),
        options: PutOptions(
          key: 'test_for_put.txt',
          region: Region.Z0,
        ));

    try {
      Future.delayed(Duration(milliseconds: 1), () {
        putTask.cancel();
      });
      final response = await putTask.toFuture();
      expect(response.key, 'test_for_put.txt');
    } catch (err) {
      expect(err, isA<DioError>());
      expect(err.type, DioErrorType.CANCEL);
    }
  });

  test('listenProgress on put method should works well.', () async {
    final putTask = storage.put(File('test_resource/test_for_put.txt'),
        options: PutOptions(
          key: 'test_for_put.txt',
          region: Region.Z0,
        ));
    int _sent, _total;
    putTask.listenProgress((sent, total) {
      _sent = sent;
      _total = total;
    });
    final response = await putTask.toFuture();
    expect(response.key, 'test_for_put.txt');
    expect(_sent / _total, equals(1));
  });

  test('putParts should works well.', () async {
    final putPartsTask = storage.putParts(
        File('test_resource/test_for_put_parts.mp4'),
        options: PutPartsOptions(
            key: 'test_for_put_parts.mp4', region: Region.Z0, chunkSize: 1));
    try {
      final response = await putPartsTask.toFuture();
      expect(response, isA<CompleteParts>());
    } catch (err) {
      if (err is DioError) {
        print(err.response);
        return;
      }
      print(err);
    }
  });

  test('putParts can be canceld.', () async {
    final putPartsTask = storage.putParts(
        File('test_resource/test_for_put_parts.mp4'),
        options: PutPartsOptions(
            key: 'test_for_put_parts.mp4', region: Region.Z0, chunkSize: 1));
    Future.delayed(Duration(milliseconds: 1), () => putPartsTask.cancel());
    try {
      await putPartsTask.toFuture();
    } catch (err) {
      expect(err, isA<DioError>());
    }
  });

  test('putParts can be resumed.', () async {
    final putPartsTask = storage.putParts(
        File('test_resource/test_for_put_parts.mp4'),
        options: PutPartsOptions(
            key: 'test_for_put_parts.mp4', region: Region.Z0, chunkSize: 1));
    Future.delayed(Duration(milliseconds: 1), () {
      putPartsTask.cancel();
    });
    try {
      await putPartsTask.toFuture();
    } catch (err) {
      expect(err, isA<DioError>());
      expect(err.type, DioErrorType.CANCEL);
    }
    Future.delayed(Duration(milliseconds: 100), () {
      putPartsTask.resume();
    });
    final response = await putPartsTask.toFuture();
    expect(response, isA<CompleteParts>());
  });

  test('listenProgress on putParts method should works well.', () async {
    // TODO
    final putPartsTask = storage.putParts(
        File('test_resource/test_for_put_parts.mp4'),
        options: PutPartsOptions(
            key: 'test_for_put_parts.mp4', region: Region.Z0, chunkSize: 1));
    int _sent, _total;
    putPartsTask.listenProgress((sent, total) {
      _sent = sent;
      _total = total;
    });
    final response = await putPartsTask.toFuture();
    expect(response, isA<CompleteParts>());
    expect(_sent / _total, equals(1));
  });
}
