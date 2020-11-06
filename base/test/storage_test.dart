import 'dart:io';
import 'package:meta/meta.dart';
import 'package:qiniu_sdk_base/src/storage/methods/put/by_part/put_parts_task.dart';
import 'package:qiniu_sdk_base/src/storage/methods/put/put_response.dart';
import 'package:test/test.dart';
import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:dotenv/dotenv.dart' show env;
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';

import 'config.dart';

void main() {
  configEnv();

  final storage = Storage();

  test('put should works well.', () async {
    final putController = PutController();
    int _sent, _total;
    putController.addProgressListener((sent, total) {
      _sent = sent;
      _total = total;
    });
    final statusList = <RequestTaskStatus>[];
    putController.addStatusListener(statusList.add);
    final response = await storage.putFile(
      File('test_resource/test_for_put.txt'),
      token,
      options: PutOptions(key: 'test_for_put.txt', controller: putController),
    );
    expect(statusList[0], RequestTaskStatus.Request);
    expect(statusList[1], RequestTaskStatus.Done);
    expect(_sent / _total, 1);
    expect(response.key, 'test_for_put.txt');
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

  test('putFileBySingle should works well.', () async {
    final putController = PutController();
    final statusList = <RequestTaskStatus>[];
    putController.addStatusListener(statusList.add);
    final response = await storage.putFileBySingle(
      File('test_resource/test_for_put.txt'),
      token,
      options: PutBySingleOptions(
        key: 'test_for_put.txt',
        controller: putController,
      ),
    );
    expect(statusList[0], RequestTaskStatus.Request);
    expect(statusList[1], RequestTaskStatus.Done);
    expect(response.key, 'test_for_put.txt');
  }, skip: !isSensitiveDataDefined);

  test('putFileBySingle can be canceled.', () async {
    final putController = PutController();

    final statusList = <RequestTaskStatus>[];
    putController.addStatusListener(statusList.add);
    final future = storage.putFileBySingle(
      File('test_resource/test_for_put.txt'),
      token,
      options: PutBySingleOptions(
          key: 'test_for_put.txt', controller: putController),
    );
    try {
      Future.delayed(Duration(milliseconds: 1), putController.cancel);
      await future;
    } catch (error) {
      expect(error, isA<DioError>());
      expect((error as DioError).type, DioErrorType.CANCEL);
    }
    expect(future, throwsA(TypeMatcher<DioError>()));
    expect(statusList[0], RequestTaskStatus.Request);
    expect(statusList[1], RequestTaskStatus.Cancel);
  }, skip: !isSensitiveDataDefined);

  test('listenProgress on putFileBySingle method should works well.', () async {
    final putController = PutController();

    int _sent, _total;
    putController.addProgressListener((sent, total) {
      _sent = sent;
      _total = total;
    });

    final response = await storage.putFileBySingle(
      File('test_resource/test_for_put.txt'),
      token,
      options: PutBySingleOptions(
        key: 'test_for_put.txt',
        controller: putController,
      ),
    );
    expect(response.key, 'test_for_put.txt');
    expect(_sent / _total, equals(1));
  }, skip: !isSensitiveDataDefined);

  test('putFileByPart should works well.', () async {
    final putController = PutController();
    final statusList = <RequestTaskStatus>[];
    putController.addStatusListener(statusList.add);
    final response = await storage.putFileByPart(
      File('test_resource/test_for_put_parts.mp4'),
      token,
      options: PutByPartOptions(
        key: 'test_for_put_parts.mp4',
        partSize: 1,
        controller: putController,
      ),
    );
    expect(response, isA<PutResponse>());
    expect(statusList[0], RequestTaskStatus.Request);
    expect(statusList[1], RequestTaskStatus.Done);
  }, skip: !isSensitiveDataDefined);

  test('putFileByPart should works well while response 612.', () async {
    final httpAdapterTest = HttpAdapterTestWith612();
    final storage = Storage(config: Config(httpClientAdapter: httpAdapterTest));

    final response = await storage.putFileByPart(
      File('test_resource/test_for_put_parts.mp4'),
      token,
      options: PutByPartOptions(key: 'test_for_put_parts.mp4', partSize: 1),
    );

    /// httpAdapterTest 应该会触发一次 612 response
    expect(httpAdapterTest.completePartsTaskResponse612, true);
    expect(response, isA<PutResponse>());
  }, skip: !isSensitiveDataDefined);

  test('putFileByPart can be canceled.', () async {
    final putController = PutController();
    final storage = Storage(config: Config(hostProvider: HostProviderTest()));
    final statusList = <RequestTaskStatus>[];
    putController
      ..addStatusListener(statusList.add)
      ..addProgressListener((sent, total) {
        // 开始上传了取消
        if (sent > 0) {
          putController.cancel();
        }
      });
    final future = storage.putFileByPart(
      File('test_resource/test_for_put_parts.mp4'),
      token,
      options: PutByPartOptions(
        key: 'test_for_put_parts.mp4',
        partSize: 1,
        controller: putController,
      ),
    );
    try {
      await future;
    } catch (error) {
      expect((error as DioError).type, DioErrorType.CANCEL);
    }
    expect(future, throwsA(TypeMatcher<DioError>()));
    expect(statusList[0], RequestTaskStatus.Request);
    expect(statusList[1], RequestTaskStatus.Cancel);
  }, skip: !isSensitiveDataDefined);

  test('putFileByPart can be resumed.', () async {
    final storage = Storage(config: Config(hostProvider: HostProviderTest()));
    final putController = PutController();

    Future.delayed(Duration(milliseconds: 1), putController.cancel);
    final future = storage.putFileByPart(
      File('test_resource/test_for_put_parts.mp4'),
      token,
      options: PutByPartOptions(
        key: 'test_for_put_parts.mp4',
        partSize: 1,
        controller: putController,
      ),
    );

    try {
      await future;
    } catch (error) {
      expect(error, isA<DioError>());
      expect((error as DioError).type, DioErrorType.CANCEL);
    }

    expect(future, throwsA(TypeMatcher<DioError>()));

    final response = await storage.putFileByPart(
      File('test_resource/test_for_put_parts.mp4'),
      token,
      options: PutByPartOptions(key: 'test_for_put_parts.mp4', partSize: 1),
    );

    expect(response, isA<PutResponse>());
  }, skip: !isSensitiveDataDefined);

  test('putFileByPart should works well with cacheProvider.', () async {
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
      file: file,
      key: key,
    );

    storage.taskManager.addRequestTask(task);

    await task.future;

    final putController = PutController();

    Future.delayed(Duration(milliseconds: 1), putController.cancel);
    final future = storage.putFileByPart(
      file,
      token,
      options:
          PutByPartOptions(key: key, partSize: 1, controller: putController),
    );

    /// 这个时候应该只缓存了初始化的缓存信息
    expect(cacheProvider.value.length, 1);

    /// 初始化的缓存 key 生成逻辑
    final cacheKey = InitPartsTask.getCacheKey(
      file.path,
      file.lengthSync(),
      key,
    );

    expect(cacheProvider.getItem(cacheKey), isA<String>());

    try {
      await future;
    } catch (error) {
      expect(error, isA<DioError>());
      expect((error as DioError).type, DioErrorType.CANCEL);
    }

    final response = await storage.putFileByPart(
      file,
      token,
      options: PutByPartOptions(key: key, partSize: 1),
    );

    expect(response, isA<PutResponse>());

    /// 上传完成后缓存应该被清理
    expect(cacheProvider.value.length, 0);
  }, skip: !isSensitiveDataDefined);

  test('listenProgress on putFileByPart method should works well.', () async {
    final putController = PutController();

    int _sent, _total;
    putController.addProgressListener((sent, total) {
      _sent = sent;
      _total = total;
    });

    final response = await storage.putFileByPart(
      File('test_resource/test_for_put_parts.mp4'),
      token,
      options: PutByPartOptions(
        key: 'test_for_put_parts.mp4',
        partSize: 1,
        controller: putController,
      ),
    );
    expect(response, isA<PutResponse>());
    expect(_sent / _total, equals(1));
  }, skip: !isSensitiveDataDefined);
}

class HttpAdapterTestWith612 extends HttpClientAdapter {
  /// 记录 CompletePartsTask 被创建的次数
  /// 第一次我们拦截并返回 612，第二次不拦截
  bool completePartsTaskResponse612 = false;
  final DefaultHttpClientAdapter _adapter = DefaultHttpClientAdapter();
  @override
  void close({bool force = false}) {
    _adapter.close(force: force);
  }

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>> requestStream, Future cancelFuture) async {
    /// 如果是 CompletePartsTask 发出去的请求，则返回 612
    if (options.path.contains('uploads/') &&
        options.method == 'POST' &&
        !completePartsTaskResponse612) {
      completePartsTaskResponse612 = true;
      return ResponseBody.fromString('', 612);
    }
    return _adapter.fetch(options, requestStream, cancelFuture);
  }
}

class HostProviderTest extends HostProvider {
  @override
  Future<String> getUpHost({@required String token}) async {
    return 'https://upload-z2.qiniup.com';
  }
}
