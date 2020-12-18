import 'dart:io';
import 'package:qiniu_sdk_base/src/storage/methods/put/by_part/put_parts_task.dart';
import 'package:test/test.dart';
import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';

import 'config.dart';

void main() {
  configEnv();

  test('retry mechanism should works well with putBySingle.', () async {
    final config = Config(
      hostProvider: HostProviderTest(),
      httpClientAdapter: HttpAdapterTestWith502(),
    );
    final storage = Storage(config: config);
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
    expect(statusList, [
      RequestTaskStatus.Init,
      RequestTaskStatus.Request,
      // 重试了 1 次
      RequestTaskStatus.Retry,
      // 重试后会重新发请求
      RequestTaskStatus.Request,
      RequestTaskStatus.Success
    ]);
    expect(response.key, 'test_for_put.txt');
  }, skip: !isSensitiveDataDefined);

  test('retry mechanism should works well with putByPart.', () async {
    final config = Config(
      hostProvider: HostProviderTest(),
      httpClientAdapter: HttpAdapterTestWith502(),
    );
    final storage = Storage(config: config);
    final file = File('test_resource/test_for_put_parts.mp4');
    final key = 'test_for_put_parts.mp4';
    final initPartsTaskStatusList = <RequestTaskStatus>[];

    // 重试阶段会发生在 InitPartsTask 调用 getUpHost 的时候
    // 手动初始化一个用于测试
    final task = InitPartsTask(
        token: token,
        file: file,
        key: key,
        controller: PutController()
          ..addStatusListener(initPartsTaskStatusList.add));
    storage.taskManager.addRequestTask(task);

    // 接下来是正常流程
    final putController = PutController();
    final statusList = <RequestTaskStatus>[];
    double _sendPercent, _totalPercent;
    putController
      ..addStatusListener(statusList.add)
      ..addProgressListener((percent) {
        _totalPercent = percent;
      })
      ..addSendProgressListener((percent) {
        _sendPercent = percent;
      });
    final response = await storage.putFileByPart(
      file,
      token,
      options: PutByPartOptions(
        key: key,
        partSize: 1,
        controller: putController,
      ),
    );
    expect(response, isA<PutResponse>());

    expect(_sendPercent, 1);
    expect(_totalPercent, 1);
    expect(
        initPartsTaskStatusList,
        equals([
          RequestTaskStatus.Init,
          RequestTaskStatus.Request,
          RequestTaskStatus.Retry,
          RequestTaskStatus.Request,
          RequestTaskStatus.Success
        ]));
    expect(statusList[0], RequestTaskStatus.Init);
    expect(statusList[1], RequestTaskStatus.Request);
    // 分片上传 PutPartsTask 本身不会重试，子任务会去重试，所以没有 Retry 状态
    expect(statusList[2], RequestTaskStatus.Success);
  }, skip: !isSensitiveDataDefined);
}

// 502 会触发服务不可用逻辑导致该 host 被冻结，并重试其他 host
class HttpAdapterTestWith502 extends HttpClientAdapter {
  final DefaultHttpClientAdapter _adapter = DefaultHttpClientAdapter();
  @override
  void close({bool force = false}) {
    _adapter.close(force: force);
  }

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>> requestStream, Future cancelFuture) async {
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
  Future<String> getUpHost({String accessKey, String bucket}) async {
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
