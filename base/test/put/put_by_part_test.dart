import 'dart:io';
import 'package:meta/meta.dart';
import 'package:qiniu_sdk_base/src/storage/error/error.dart';
import 'package:qiniu_sdk_base/src/storage/methods/put/by_part/put_parts_task.dart';
import 'package:qiniu_sdk_base/src/storage/methods/put/put_response.dart';
import 'package:test/test.dart';
import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';

import '../config.dart';
import 'put_controller_builder.dart';

void main() {
  configEnv();
  test('putFileByPart should works well.', () async {
    final storage = Storage();
    final pcb = PutControllerBuilder();
    var callnumber = 0;
    pcb.putController.addSendProgressListener((percent) {
      callnumber++;
    });
    final file = File('test_resource/test_for_put_parts.mp4');
    final response = await storage.putFileByPart(
      file,
      token,
      options: PutByPartOptions(
        key: 'test_for_put_parts.mp4',
        partSize: 1,
        controller: pcb.putController,
      ),
    );
    expect(response, isA<PutResponse>());
    // 2 片分片所以 2 次
    expect(callnumber, 2);

    pcb.testAll();

    // 不设置参数的情况
    final responseNoOps = await storage.putFileByPart(
      file,
      token,
    );

    expect(responseNoOps, isA<PutResponse>());
  }, skip: !isSensitiveDataDefined);

  test('putFileByPart should throw error with incorrect partSize.', () async {
    final storage = Storage();
    try {
      await storage.putFileByPart(
        File('test_resource/test_for_put_parts.mp4'),
        token,
        options: PutByPartOptions(partSize: 0),
      );
    } catch (e) {
      expect(e, isA<RangeError>());
    }

    try {
      await storage.putFileByPart(
        File('test_resource/test_for_put_parts.mp4'),
        token,
        options: PutByPartOptions(partSize: 1025),
      );
    } catch (e) {
      expect(e, isA<RangeError>());
    }
  });

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

  test('putFileByPart can be cancelled.', () async {
    final pcb = PutControllerBuilder();
    final storage = Storage(config: Config(hostProvider: HostProviderTest()));
    final file = File('test_resource/test_for_put_parts.mp4');
    final key = 'test_for_put_parts.mp4';
    pcb.putController.addSendProgressListener((percent) {
      // 开始上传并且 InitPartsTask 设置完缓存后取消
      if (percent > 0.1) {
        pcb.putController.cancel();
      }
    });
    var future = storage.putFileByPart(
      file,
      token,
      options: PutByPartOptions(
        key: key,
        partSize: 1,
        controller: pcb.putController,
      ),
    );
    try {
      await future;
    } catch (error) {
      expect((error as StorageError).type, StorageErrorType.CANCEL);
    }
    expect(future, throwsA(TypeMatcher<StorageError>()));
    pcb.testStatus(targetStatusList: [
      StorageStatus.Init,
      StorageStatus.Request,
      StorageStatus.Cancel
    ], targetProgressList: [
      0.001,
      0.002,
    ]);

    try {
      await storage.putFileByPart(
        file,
        token,
        options: PutByPartOptions(
          key: key,
          partSize: 1,
          controller: pcb.putController,
        ),
      );
    } catch (error) {
      // 复用了相同的 controller，所以也会触发取消的错误
      expect(error, isA<StorageError>());
      expect((error as StorageError).type, StorageErrorType.CANCEL);
    }

    expect(future, throwsA(isA<StorageError>()));

    final response = await storage.putFileByPart(
      file,
      token,
      options: PutByPartOptions(key: key, partSize: 1),
    );
    expect(response, isA<PutResponse>());
  }, skip: !isSensitiveDataDefined);

  test('putFileByPart can be resumed.', () async {
    final storage = Storage(config: Config(hostProvider: HostProviderTest()));
    final putController = PutController();
    putController.addSendProgressListener((percent) {
      // 开始上传了取消
      if (percent > 0.1) {
        putController.cancel();
      }
    });

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
      expect(error, isA<StorageError>());
      expect((error as StorageError).type, StorageErrorType.CANCEL);
    }

    expect(future, throwsA(TypeMatcher<StorageError>()));

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
    final task = InitPartsTask(token: token, file: file, key: key);

    storage.taskManager.addRequestTask(task);

    await task.future;

    final putController = PutController();

    putController.addSendProgressListener((percent) {
      if (percent > 0.5) {
        putController.cancel();
      }
    });

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
    cacheProvider.clear();

    try {
      await future;
    } catch (error) {
      expect(error, isA<StorageError>());
      expect((error as StorageError).type, StorageErrorType.CANCEL);
    }

    cacheProvider.clear();

    final response = await storage.putFileByPart(
      file,
      token,
      options: PutByPartOptions(key: key, partSize: 1),
    );

    expect(response, isA<PutResponse>());

    /// 上传完成后缓存应该被清理
    expect(cacheProvider.value.length, 0);
  }, skip: !isSensitiveDataDefined);

  test(
      'putFileByPart should throw error while there is a same task is working.',
      () async {
    final cacheProvider = DefaultCacheProvider();
    final config = Config(cacheProvider: cacheProvider);
    final storage = Storage(config: config);
    final file = File('test_resource/test_for_put_parts.mp4');
    final key = 'test_for_put_parts.mp4';

    /// 初始化的缓存 key 生成逻辑
    final cacheKey = InitPartsTask.getCacheKey(
      file.path,
      file.lengthSync(),
      key,
    );

    var errorOccurred = false;

    final putController = PutController()
      ..addSendProgressListener((_) async {
        try {
          if (cacheProvider.getItem(cacheKey) != null) {
            await storage.putFileByPart(
              file,
              token,
              options: PutByPartOptions(
                key: key,
                partSize: 1,
              ),
            );
          }
        } catch (e) {
          errorOccurred = true;
          expect(e, isA<StorageError>());
          expect((e as StorageError).type, StorageErrorType.IN_PROGRESS);
        }
      });

    await storage.putFileByPart(
      file,
      token,
      options: PutByPartOptions(
        key: key,
        partSize: 1,
        controller: putController,
      ),
    );

    expect(errorOccurred, true);

    /// 上传完成后缓存应该被清理
    expect(cacheProvider.value.length, 0);
  }, skip: !isSensitiveDataDefined);

  test('putFileByPart\'s status and progress should works well.', () async {
    final storage = Storage();
    final pcb = PutControllerBuilder();

    final response = await storage.putFileByPart(
      File('test_resource/test_for_put_parts.mp4'),
      token,
      options: PutByPartOptions(
        key: 'test_for_put_parts.mp4',
        partSize: 1,
        controller: pcb.putController,
      ),
    );
    expect(response, isA<PutResponse>());
    pcb
      ..testProcess()
      ..testStatus(targetProgressList: [0.001, 0.002, 0.99, 1]);
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
  Future<String> getUpHost({
    @required String accessKey,
    @required String bucket,
  }) async {
    return 'https://upload-z2.qiniup.com';
  }

  @override
  void freezeHost(String host) {}

  @override
  bool isFrozen(String host) {
    return false;
  }
}
