import 'dart:io';
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
    expect(statusList[0], RequestTaskStatus.Init);
    expect(statusList[1], RequestTaskStatus.Request);
    // 重试了 1 次
    expect(statusList[2], RequestTaskStatus.Request);
    expect(statusList[3], RequestTaskStatus.Success);
    expect(response.key, 'test_for_put.txt');
  }, skip: !isSensitiveDataDefined);

  test('retry mechanism should works well with putByPart.', () async {
    final config = Config(
      hostProvider: HostProviderTest(),
      httpClientAdapter: HttpAdapterTestWith502(),
    );
    final storage = Storage(config: config);
    final putController = PutController();
    final statusList = <RequestTaskStatus>[];
    int _sent, _total;
    putController
      ..addStatusListener(statusList.add)
      ..addProgressListener((sent, total) {
        _sent = sent;
        _total = total;
      });
    final file = File('test_resource/test_for_put_parts.mp4');
    final response = await storage.putFileByPart(
      file,
      token,
      options: PutByPartOptions(
        key: 'test_for_put_parts.mp4',
        partSize: 1,
        controller: putController,
      ),
    );
    expect(response, isA<PutResponse>());

    /// 分片上传会给 _sent _total + 1
    expect(_sent - 1, file.lengthSync());
    expect(_total - 1, file.lengthSync());
    expect(_sent / _total, 1);
    expect(statusList[0], RequestTaskStatus.Init);
    expect(statusList[1], RequestTaskStatus.Request);
    // 重试了一次
    expect(statusList[2], RequestTaskStatus.Request);
    expect(statusList[3], RequestTaskStatus.Success);
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
