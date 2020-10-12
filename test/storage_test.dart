import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dotenv/dotenv.dart' show env;
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';
import 'package:qiniu_sdk_base/src/task/put_parts_task/put_parts_task.dart';
import 'package:qiniu_sdk_base/src/storage.dart';

import 'package:test/test.dart';

import 'config.dart';

void main() {
  configEnv();

  Storage storage;
  setUpAll(() {
    storage = Storage();
  });

  test('put should works well.', () async {
    final putTask = storage.putFile(
      File('test_resource/test_for_put.txt'),
      token,
      options: PutOptions(key: 'test_for_put.txt'),
    );
    final response = await putTask.future;
    expect(response.key, 'test_for_put.txt');
  }, skip: !isSensitiveDataDefined);

  test('put can be canceled.', () async {
    final putTask = storage.putFile(
      File('test_resource/test_for_put.txt'),
      token,
      options: PutOptions(key: 'test_for_put.txt'),
    );

    try {
      Future.delayed(Duration(milliseconds: 1), putTask.cancel);
      final response = await putTask.future;
      expect(response.key, 'test_for_put.txt');
    } catch (err) {
      expect(err, isA<DioError>());
      expect(err.type, DioErrorType.CANCEL);
    }
  }, skip: !isSensitiveDataDefined);

  test('listenProgress on put method should works well.', () async {
    final putTask = storage.putFile(
      File('test_resource/test_for_put.txt'),
      token,
      options: PutOptions(key: 'test_for_put.txt'),
    );
    int _sent, _total;
    putTask.addProgressListener((sent, total) {
      _sent = sent;
      _total = total;
    });
    final response = await putTask.future;
    expect(response.key, 'test_for_put.txt');
    expect(_sent / _total, equals(1));
  }, skip: !isSensitiveDataDefined);

  test('putParts should works well.', () async {
    final putPartsTask = storage.putFileParts(
      File('test_resource/test_for_put_parts.mp4'),
      token,
      options: PutPartsOptions(key: 'test_for_put_parts.mp4', partSize: 1),
    );
    final response = await putPartsTask.future;
    expect(response, isA<CompleteParts>());
  }, skip: !isSensitiveDataDefined);

  test('putParts can be canceled.', () async {
    final storage = Storage(config: Config(hostProvider: TestHostProvider()));
    final putPartsTask = storage.putFileParts(
      File('test_resource/test_for_put_parts.mp4'),
      token,
      options: PutPartsOptions(key: 'test_for_put_parts.mp4', partSize: 1),
    );
    Future.delayed(Duration(milliseconds: 1), putPartsTask.cancel);
    try {
      await putPartsTask.future;
    } catch (err) {
      expect(err.type, DioErrorType.CANCEL);
    }
    expect(putPartsTask.future, throwsA(TypeMatcher<DioError>()));
  }, skip: !isSensitiveDataDefined);

  test('putParts can be resumed.', () async {
    final storage = Storage(config: Config(hostProvider: TestHostProvider()));
    final putPartsTask = storage.putFileParts(
      File('test_resource/test_for_put_parts.mp4'),
      token,
      options: PutPartsOptions(key: 'test_for_put_parts.mp4', partSize: 1),
    );

    Future.delayed(Duration(milliseconds: 1), putPartsTask.cancel);

    try {
      await putPartsTask.future;
    } catch (err) {
      expect(err, isA<DioError>());
      expect(err.type, DioErrorType.CANCEL);
    }

    expect(putPartsTask.future, throwsA(TypeMatcher<DioError>()));

    final response = await storage
        .putFileParts(
          File('test_resource/test_for_put_parts.mp4'),
          token,
          options: PutPartsOptions(key: 'test_for_put_parts.mp4', partSize: 1),
        )
        .future;

    expect(response, isA<CompleteParts>());
  }, skip: !isSensitiveDataDefined);

  test('putParts should works well with cacheProvider.', () async {
    final cacheProvider = DefaultCacheProvider();
    final config = Config(cacheProvider: cacheProvider);
    final storage = Storage(config: config);
    final file = File('test_resource/test_for_put_parts.mp4');
    final key = 'test_for_put_parts.mp4';

    /// 手动初始化一个初始化文件的任务，确定分片上传的第一步会被缓存
    final task = InitPartsTask(
      token: token,
      host: await config.hostProvider.getUpHost(token: token),

      /// TOKEN_SCOPE 暂时只保存了 bucket 信息
      bucket: env['QINIU_DART_SDK_TOKEN_SCOPE'],
      key: key,
      file: file,
    );

    storage.taskManager.addRequestTask(task);

    await task.future;

    final putPartsTask = storage.putFileParts(
      file,
      token,
      options: PutPartsOptions(key: key, partSize: 1),
    );

    Future.delayed(Duration(milliseconds: 1), putPartsTask.cancel);

    /// 这个时候应该只缓存了初始化的缓存信息
    expect(cacheProvider.value.length, 1);

    /// 初始化的缓存 key 生成逻辑
    final cacheKey =
        InitPartsTask.getCacheKey(file.path, key, file.lengthSync());

    expect(cacheProvider.getItem(cacheKey), isA<String>());

    try {
      await putPartsTask.future;
    } catch (err) {
      expect(err, isA<DioError>());
      expect(err.type, DioErrorType.CANCEL);
    }

    final response = await storage
        .putFileParts(
          file,
          token,
          options: PutPartsOptions(key: key, partSize: 1),
        )
        .future;

    expect(response, isA<CompleteParts>());

    /// 上传完成后缓存应该被清理
    expect(cacheProvider.value.length, 0);
  }, skip: !isSensitiveDataDefined);

  test('listenProgress on putParts method should works well.', () async {
    final putPartsTask = storage.putFileParts(
      File('test_resource/test_for_put_parts.mp4'),
      token,
      options: PutPartsOptions(key: 'test_for_put_parts.mp4', partSize: 1),
    );
    int _sent, _total;
    putPartsTask.addProgressListener((sent, total) {
      _sent = sent;
      _total = total;
    });
    final response = await putPartsTask.future;
    expect(response, isA<CompleteParts>());
    expect(_sent / _total, equals(1));
  }, skip: !isSensitiveDataDefined);
}

class TestHostProvider extends HostProvider {
  @override
  Future<String> getUpHost({String token}) async {
    return 'https://upload-z2.qiniup.com';
  }
}
