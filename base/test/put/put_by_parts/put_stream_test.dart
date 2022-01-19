@Timeout(Duration(seconds: 60))
import 'package:dotenv/dotenv.dart' show env;
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';
import 'package:qiniu_sdk_base/src/storage/methods/put/by_part/put_parts_task.dart';
import 'package:qiniu_sdk_base/src/storage/resource/resource.dart';
import 'package:test/test.dart';

import '../../config.dart';
import '../helpers.dart';

void main() {
  configEnv();

  final fileLength = fileForPart.lengthSync();

  test('customVars&returnBody customVars should works well.', () async {
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

    final response = await storage.putStream(
      fileForPart.openRead(),
      token,
      fileLength,
      options: PutOptions(
        key: fileKeyForPart,
        partSize: 1,
        customVars: customVars,
      ),
    );

    expect(response.key, fileKeyForPart);
    expect(response.rawData['type'], 'testXType');
    expect(response.rawData['ext'], 'testXExt');
  }, skip: !isSensitiveDataDefined);

  test('putStream should works well.', () async {
    final storage = Storage();
    final pcb = PutControllerBuilder();
    var callnumber = 0;
    pcb.putController.addSendProgressListener((percent) {
      callnumber++;
    });
    final response = await storage.putStream(
      fileForPart.openRead(),
      token,
      fileLength,
      options: PutOptions(
        key: fileKeyForPart,
        partSize: 1,
        controller: pcb.putController,
      ),
    );
    expect(response, isA<PutResponse>());
    // 2 片分片所以 2 次
    expect(callnumber, 2);

    pcb.testAll();

    // 不设置参数的情况
    final responseNoOps = await storage.putStream(
      fileForPart.openRead(),
      token,
      fileLength,
    );

    expect(responseNoOps, isA<PutResponse>());
  }, skip: !isSensitiveDataDefined);

  test('putStream should throw error with incorrect partSize.', () async {
    final storage = Storage();
    try {
      await storage.putStream(
        fileForPart.openRead(),
        token,
        fileLength,
        options: PutOptions(
          key: fileKeyForPart,
          partSize: 0,
        ),
      );
    } catch (e) {
      expect(e, isA<AssertionError>());
    }

    try {
      await storage.putStream(
        fileForPart.openRead(),
        token,
        fileLength,
        options: PutOptions(
          key: fileKeyForPart,
          partSize: 1025,
        ),
      );
    } catch (e) {
      expect(e, isA<AssertionError>());
    }
  }, skip: !isSensitiveDataDefined);

  test('putStream should works well while response 612.', () async {
    final httpAdapterTest = HttpAdapterTestWith612();
    final storage = Storage(config: Config(httpClientAdapter: httpAdapterTest));

    try {
      await storage.putStream(
        fileForPart.openRead(),
        token,
        fileLength,
        options: PutOptions(
          key: fileKeyForPart,
          partSize: 1,
        ),
      );
    } catch (e) {
      /// httpAdapterTest 应该会触发一次 612 response
      expect(httpAdapterTest.completePartsTaskResponse612, true);
      expect(e, isA<StorageError>());
      expect((e as StorageError).code, 612);
    }
  }, skip: !isSensitiveDataDefined);

  test('putStream can be cancelled.', () async {
    final pcb = PutControllerBuilder();
    final storage = Storage(config: Config(hostProvider: HostProviderTest()));
    final key = fileKeyForPart;
    pcb.putController.addSendProgressListener((percent) {
      // 开始上传并且 InitPartsTask 设置完缓存后取消
      if (percent > 0.1) {
        pcb.putController.cancel();
      }
    });
    var future = storage.putStream(
      fileForPart.openRead(),
      token,
      fileLength,
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
      await storage.putStream(
        fileForPart.openRead(),
        token,
        fileLength,
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

    final response = await storage.putStream(
      fileForPart.openRead(),
      token,
      fileLength,
      options: PutOptions(key: key, partSize: 1),
    );
    expect(response, isA<PutResponse>());
  }, skip: !isSensitiveDataDefined);

  test('putStream can be resumed.', () async {
    final storage = Storage(config: Config(hostProvider: HostProviderTest()));
    final putController = PutController();
    putController.addSendProgressListener((percent) {
      // 开始上传了取消
      if (percent > 0.1) {
        putController.cancel();
      }
    });

    final future = storage.putStream(
      fileForPart.openRead(),
      token,
      fileLength,
      options: PutOptions(
        key: fileKeyForPart,
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

    final response = await storage.putStream(
      fileForPart.openRead(),
      token,
      fileLength,
      options: PutOptions(key: fileKeyForPart, partSize: 1),
    );

    expect(response, isA<PutResponse>());
  }, skip: !isSensitiveDataDefined);

  test('putstream should throw error if there is a same task is working.',
      () async {
    final storage = Storage();
    final key = fileKeyForPart;

    var errorOccurred = false;

    // 故意不 await，让后面发送一个相同的任务
    // ignore: unawaited_futures
    storage.putStream(
      fileForPart.openRead(),
      token,
      fileLength,
      id: 'test',
      options: PutOptions(
        key: key,
        partSize: 1,
      ),
    );

    try {
      await storage.putStream(
        fileForPart.openRead(),
        token,
        fileLength,
        id: 'test',
        options: PutOptions(
          key: key,
          partSize: 1,
        ),
      );
    } catch (e) {
      errorOccurred = true;
      expect(e, isA<StorageError>());
      expect((e as StorageError).type, StorageErrorType.IN_PROGRESS);
    }
    expect(errorOccurred, true);
  }, skip: !isSensitiveDataDefined);

  test('putStream should works well with cacheProvider.', () async {
    final cacheProvider = CacheProviderForTest();
    final config = Config(cacheProvider: cacheProvider);
    final storage = Storage(config: config);
    final key = fileKeyForPart;
    final resource =
        StreamResource(stream: fileForPart.openRead(), length: fileLength);

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

    final future = storage.putStream(
      fileForPart.openRead(),
      token,
      fileLength,
      options: PutOptions(
        key: key,
        partSize: 1,
        controller: putController,
      ),
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

    final response = await storage.putStream(
      fileForPart.openRead(),
      token,
      fileLength,
      options: PutOptions(
        key: key,
        partSize: 1,
      ),
    );

    expect(response, isA<PutResponse>());

    /// 上传完成后缓存应该被清理
    expect(cacheProvider.value.length, 0);
    // init + 2 个分片 2 次 = 3 次
    expect(cacheProvider.callNumber, 3);
  }, skip: !isSensitiveDataDefined);

  test('putStream\'s status and progress should works well.', () async {
    final storage = Storage();
    final pcb = PutControllerBuilder();

    final response = await storage.putStream(
      fileForPart.openRead(),
      token,
      fileLength,
      options: PutOptions(
        key: fileKeyForPart,
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
