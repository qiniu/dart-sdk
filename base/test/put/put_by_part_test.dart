@Timeout(Duration(seconds: 60))
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:dotenv/dotenv.dart' show env;
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';
import 'package:qiniu_sdk_base/src/storage/methods/put/by_part/put_parts_task.dart';
import 'package:qiniu_sdk_base/src/storage/resource/resource.dart';
import 'package:test/test.dart';

import '../config.dart';
import 'put_controller_builder.dart';

void main() {
  configEnv();

  test('putFileByPart customVars should works well.', () async {
    final storage = Storage();

    final auth = Auth(
      accessKey: env['QINIU_DART_SDK_ACCESS_KEY']!,
      secretKey: env['QINIU_DART_SDK_SECRET_KEY']!,
    );

    final token = auth.generateUploadToken(
      putPolicy: PutPolicy(
        insertOnly: 0,
        scope: env['QINIU_DART_SDK_TOKEN_SCOPE']!,
        returnBody: '{"key":"\$(key)","type":"\$(x:type)","ext":"\$(x:ext)"}',
        deadline: DateTime.now().millisecondsSinceEpoch + 3600,
      ),
    );

    var customVars = <String, String>{
      'x:type': 'testXType',
      'x:ext': 'testXExt',
    };

    var putController = PutController();
    final file = File('test_resource/test_for_put_parts.mp4');
    final response = await storage.putFile(
      file,
      token,
      options: PutOptions(
        key: 'test_for_put_parts.mp4',
        partSize: 1,
        customVars: customVars,
        controller: putController,
      ),
    );

    expect(response.key, 'test_for_put_parts.mp4');
    expect(response.rawData['type'], 'testXType');
    expect(response.rawData['ext'], 'testXExt');
  }, skip: !isSensitiveDataDefined);

  test('putFileByPart should works well.', () async {
    final storage = Storage();
    final pcb = PutControllerBuilder();
    var callnumber = 0;
    pcb.putController.addSendProgressListener((percent) {
      callnumber++;
    });
    final file = File('test_resource/test_for_put_parts.mp4');
    final response = await storage.putFile(
      file,
      token,
      options: PutOptions(
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
    final responseNoOps = await storage.putFile(
      file,
      token,
    );

    expect(responseNoOps, isA<PutResponse>());
  }, skip: !isSensitiveDataDefined);

  test('putFileByPart should throw error with incorrect partSize.', () async {
    final storage = Storage();
    final file = File('test_resource/test_for_put_parts.mp4');
    try {
      await storage.putFile(
        file,
        token,
        options: PutOptions(partSize: 0),
      );
    } catch (e) {
      expect(e, isA<AssertionError>());
    }

    try {
      await storage.putFile(
        file,
        token,
        options: PutOptions(partSize: 1025),
      );
    } catch (e) {
      expect(e, isA<AssertionError>());
    }
  }, skip: !isSensitiveDataDefined);

  test('putFileByPart should works well while response 612.', () async {
    final httpAdapterTest = HttpAdapterTestWith612();
    final storage = Storage(config: Config(httpClientAdapter: httpAdapterTest));
    final response = await storage.putFile(
      File('test_resource/test_for_put_parts.mp4'),
      token,
      options: PutOptions(key: 'test_for_put_parts.mp4', partSize: 1),
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
    var future = storage.putFile(
      file,
      token,
      options: PutOptions(
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
      await storage.putFile(
        file,
        token,
        options: PutOptions(
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

    final response = await storage.putFile(
      file,
      token,
      options: PutOptions(key: key, partSize: 1),
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

    final future = storage.putFile(
      File('test_resource/test_for_put_parts.mp4'),
      token,
      options: PutOptions(
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

    final response = await storage.putFile(
      File('test_resource/test_for_put_parts.mp4'),
      token,
      options: PutOptions(key: 'test_for_put_parts.mp4', partSize: 1),
    );

    expect(response, isA<PutResponse>());
  }, skip: !isSensitiveDataDefined);

  test('putFileByPart should works well with cacheProvider.', () async {
    final cacheProvider = CacheProviderForTest();
    final config = Config(cacheProvider: cacheProvider);
    final storage = Storage(config: config);
    final file = File('test_resource/test_for_put_parts.mp4');
    final key = 'test_for_put_parts.mp4';
    final resource = FileResource(file: file, length: file.lengthSync());

    /// 手动初始化一个初始化文件的任务，确定分片上传的第一步会被缓存
    final task = InitPartsTask(
      token: token,
      resource: resource,
      key: key,
    );

    storage.taskManager.addTask(task);

    await task.future;

    final putController = PutController();

    putController.addSendProgressListener((percent) {
      // 因为一共 2 个分片，取 0.5 一个完成后就取消
      if (percent > 0.5) {
        putController.cancel();
      }
    });

    final future = storage.putFile(
      file,
      token,
      options: PutOptions(key: key, partSize: 1, controller: putController),
    );

    /// 这个时候应该只缓存了初始化的缓存信息
    expect(cacheProvider.value.length, 1);

    /// 初始化的缓存 key 生成逻辑
    final cacheKey = InitPartsTask.getCacheKey(
      resource.id,
      key,
    );

    expect(await cacheProvider.getItem(cacheKey), isA<String>());
    await cacheProvider.clear();

    try {
      await future;
    } catch (error) {
      expect(error, isA<StorageError>());
      expect((error as StorageError).type, StorageErrorType.CANCEL);
      // 每个分片完成后会保存一次
      // init 一次，仅有的一个分片完成后一次共 2 次
      expect(cacheProvider.callNumber, 2);
    }

    await cacheProvider.clear();
    cacheProvider.callNumber = 0;

    final response = await storage.putFile(
      file,
      token,
      options: PutOptions(key: key, partSize: 1),
    );

    expect(response, isA<PutResponse>());

    /// 上传完成后缓存应该被清理
    expect(cacheProvider.value.length, 0);
    // init + 2 个分片 2 次 = 3 次
    expect(cacheProvider.callNumber, 3);
  }, skip: !isSensitiveDataDefined);

  test('putFileByPart\'s status and progress should works well.', () async {
    final storage = Storage();
    final pcb = PutControllerBuilder();

    final response = await storage.putFile(
      File('test_resource/test_for_put_parts.mp4'),
      token,
      options: PutOptions(
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

  test('putBytes should works well.', () async {
    final storage = Storage();
    final pcb = PutControllerBuilder();
    var callnumber = 0;
    pcb.putController.addSendProgressListener((percent) {
      callnumber++;
    });
    final file = File('test_resource/test_for_put_parts.mp4');
    final response = await storage.putBytes(
      file.readAsBytesSync(),
      token,
      options: PutOptions(
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
    final responseNoOps = await storage.putBytes(
      file.readAsBytesSync(),
      token,
    );

    expect(responseNoOps, isA<PutResponse>());
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
      Stream<Uint8List>? requestStream, Future? cancelFuture) async {
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
    required String accessKey,
    required String bucket,
  }) async {
    // token 中 bucket 对应的地区
    return 'https://upload-na0.qiniup.com';
  }

  @override
  void freezeHost(String host) {}

  @override
  bool isFrozen(String host) {
    return false;
  }
}

class CacheProviderForTest extends DefaultCacheProvider {
  int callNumber = 0;
  @override
  // ignore: unnecessary_overrides
  Future setItem(String key, String item) {
    callNumber++;
    return super.setItem(key, item);
  }
}
