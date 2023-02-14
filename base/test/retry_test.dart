@Timeout(Duration(seconds: 60))
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';
import 'package:qiniu_sdk_base/src/storage/methods/put/by_part/put_parts_task.dart';
import 'package:qiniu_sdk_base/src/storage/resource/resource.dart';
import 'package:test/test.dart';

import 'config.dart';

void main() {
  configEnv();

  test(
    'putBySingle\'s retry mechanism should throw error directly while cannot connect to host.',
    () async {
      final httpAdapter = HttpAdapterTestWithConnectFailedToHost(0);
      final config = Config(
        hostProvider: HostProviderTest(),
        httpClientAdapter: httpAdapter,
        retryLimit: 3,
      );
      final storage = Storage(config: config);
      final statusList = <StorageStatus>[];
      final future = storage.putFile(
        File('test_resource/test_for_put.txt'),
        token,
        options: PutOptions(
          controller: PutController()..addStatusListener(statusList.add),
        ),
      );
      try {
        await future;
      } catch (error) {
        expect(error, isA<StorageError>());
        expect((error as StorageError).type, StorageErrorType.UNKNOWN);
      }
      expect(future, throwsA(isA<StorageError>()));
      // 初始 1 次 + 重试 3 次
      expect(httpAdapter.callTimes, 4);
      expect(statusList, [
        StorageStatus.Init,
        StorageStatus.Request,
        StorageStatus.Retry,
        StorageStatus.Request,
        StorageStatus.Retry,
        StorageStatus.Request,
        StorageStatus.Retry,
        StorageStatus.Request,
        StorageStatus.Error
      ]);
    },
    skip: !isSensitiveDataDefined,
  );

  test(
    'putFileByPart\'s retry mechanism should throw error directly while cannot connect to host.',
    () async {
      final httpAdapter = HttpAdapterTestWithConnectFailedToHost(1);
      final cacheProvider = DefaultCacheProvider();
      final config = Config(
        cacheProvider: cacheProvider,
        hostProvider: HostProviderTest(),
        httpClientAdapter: httpAdapter,
      );
      final storage = Storage(config: config);
      final file = File('test_resource/test_for_put_parts.mp4');
      final resource = FileResource(file: file, length: file.lengthSync());
      final statusList = <StorageStatus>[];
      // 设置一个假的初始化缓存，让分片上传跳过初始化文件，便于测试后面的上传文件流程
      await cacheProvider.setItem(
        InitPartsTask.getCacheKey(resource.id, null),
        json.encode({'expireAt': 0, 'uploadId': '0'}),
      );
      final future = storage.putFile(
        file,
        token,
        options: PutOptions(
          partSize: 1,
          controller: PutController()..addStatusListener(statusList.add),
        ),
      );
      try {
        await future;
      } catch (error) {
        expect(error, isA<StorageError>());
        expect((error as StorageError).type, StorageErrorType.UNKNOWN);
      }
      expect(future, throwsA(isA<StorageError>()));
      // UploadPartTask 4 次 * 2 个分片
      expect(httpAdapter.callTimes, 8);
      expect(
        statusList,
        [StorageStatus.Init, StorageStatus.Request, StorageStatus.Error],
      );
    },
    skip: !isSensitiveDataDefined,
  );

  test(
    'retry mechanism should works well with putBySingle while host is unavailable.',
    () async {
      final config = Config(
        hostProvider: HostProviderTest(),
        httpClientAdapter: HttpAdapterTestWith502(),
      );
      final storage = Storage(config: config);
      final putController = PutController();
      final statusList = <StorageStatus>[];
      putController.addStatusListener(statusList.add);
      final response = await storage.putFile(
        File('test_resource/test_for_put.txt'),
        token,
        options: PutOptions(
          forceBySingle: true,
          key: 'test_for_put.txt',
          controller: putController,
        ),
      );
      expect(statusList, [
        StorageStatus.Init,
        StorageStatus.Request,
        // 重试了 1 次
        StorageStatus.Retry,
        // 重试后会重新发请求
        StorageStatus.Request,
        StorageStatus.Success
      ]);
      expect(response.key, 'test_for_put.txt');
    },
    skip: !isSensitiveDataDefined,
  );

  test(
    'retry mechanism should works well with putByPart while host is unavailable.',
    () async {
      final config = Config(
        hostProvider: HostProviderTest(),
        httpClientAdapter: HttpAdapterTestWith502(),
      );
      final storage = Storage(config: config);
      final file = File('test_resource/test_for_put_parts.mp4');
      final resource = FileResource(file: file, length: file.lengthSync());
      final key = 'test_for_put_parts.mp4';
      final initPartsTaskStatusList = <StorageStatus>[];

      // 重试阶段会发生在 InitPartsTask 调用 getUpHost 的时候
      // 手动初始化一个用于测试
      final task = InitPartsTask(
        token: token,
        resource: resource,
        key: key,
        controller: PutController()
          ..addStatusListener(initPartsTaskStatusList.add),
      );
      storage.taskManager.addTask(task);

      // 接下来是正常流程
      final putController = PutController();
      final statusList = <StorageStatus>[];
      late double sendPercent, totalPercent;
      putController
        ..addStatusListener(statusList.add)
        ..addProgressListener((percent) {
          totalPercent = percent;
        })
        ..addSendProgressListener((percent) {
          sendPercent = percent;
        });
      final response = await storage.putFile(
        file,
        token,
        options: PutOptions(
          key: key,
          partSize: 1,
          controller: putController,
        ),
      );
      expect(response, isA<PutResponse>());

      expect(sendPercent, 1);
      expect(totalPercent, 1);
      expect(
        initPartsTaskStatusList,
        equals([
          StorageStatus.Init,
          StorageStatus.Request,
          StorageStatus.Retry,
          StorageStatus.Request,
          StorageStatus.Success
        ]),
      );
      expect(statusList[0], StorageStatus.Init);
      expect(statusList[1], StorageStatus.Request);
      // 分片上传 PutPartsTask 本身不会重试，子任务会去重试，所以没有 Retry 状态
      expect(statusList[2], StorageStatus.Success);
    },
    skip: !isSensitiveDataDefined,
  );
}

// 会扔出 DioError，错误类型是 DioErrorType.other，每个请求调用了 3 次
class HttpAdapterTestWithConnectFailedToHost implements HttpClientAdapter {
  int callTimes = 0;
  final HttpClientAdapter _adapter = HttpClientAdapter();
  // 0 single, 1 parts
  int type = 0;
  HttpAdapterTestWithConnectFailedToHost(this.type);
  @override
  void close({bool force = false}) {
    _adapter.close(force: force);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    if (options.path.contains('test.com')) {
      if ((type == 0 && options.method == 'POST') ||
          (type == 1 && options.method == 'PUT')) {
        callTimes++;
        // 尝试扔出一个会触发连不上 host 的 错误
        throw DioError(requestOptions: options);
      }
    }
    return _adapter.fetch(options, requestStream, cancelFuture);
  }
}

// 502 会触发服务不可用逻辑导致该 host 被冻结，并重试其他 host
class HttpAdapterTestWith502 implements HttpClientAdapter {
  final HttpClientAdapter _adapter = HttpClientAdapter();
  @override
  void close({bool force = false}) {
    _adapter.close(force: force);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    if (options.path.contains('test.com') && options.method == 'POST') {
      return ResponseBody.fromString('', 502);
    }
    return _adapter.fetch(options, requestStream, cancelFuture);
  }
}

class HostProviderTest extends HostProvider {
  final _hostProvider = DefaultHostProvider();
  @override
  void freezeHost(String host) {
    _hostProvider.freezeHost(host);
  }

  @override
  Future<String> getUpHost({
    required String accessKey,
    required String bucket,
  }) async {
    if (isFrozen('https://test.com')) {
      return _hostProvider.getUpHost(accessKey: accessKey, bucket: bucket);
    }
    return 'https://test.com';
  }

  @override
  bool isFrozen(String host) {
    return _hostProvider.isFrozen(host);
  }
}
