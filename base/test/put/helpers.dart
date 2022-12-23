import 'dart:io';
import 'dart:typed_data';

import 'package:diox/diox.dart';
import 'package:qiniu_sdk_base_diox/qiniu_sdk_base.dart';
import 'package:qiniu_sdk_base_diox/src/storage/config/config.dart';
import 'package:test/test.dart';

final fileForPart = File('test_resource/test_for_put_parts.mp4');
final fileForSingle = File('test_resource/test_for_put.txt');
final fileKeyForSingle = 'test_for_put.txt';
final fileKeyForPart = 'test_for_put_parts.mp4';

class PutControllerBuilder {
  final putController = PutController();
  final statusList = <StorageStatus>[];
  final progressList = <double>[];
  late double _sendPercent, _totalPercent;

  PutControllerBuilder() {
    putController
      ..addStatusListener(statusList.add)
      ..addProgressListener((percent) {
        progressList.add(percent);
        _totalPercent = percent;
      })
      ..addSendProgressListener((percent) {
        _sendPercent = percent;
      });
  }

  void testAll() {
    testProcess();
    testStatus();
  }

  // 任务执行完成后执行此方法
  void testProcess() {
    expect(_sendPercent, _totalPercent);
    expect(_sendPercent, 1);
    expect(_totalPercent, 1);
  }

  // 任务执行完成后执行此方法
  void testStatus({
    List<StorageStatus>? targetStatusList,
    List<double>? targetProgressList,
  }) {
    targetStatusList ??= [
      StorageStatus.Init,
      StorageStatus.Request,
      StorageStatus.Success
    ];
    targetProgressList ??= [0.001, 0.99, 1];
    expect(statusList, equals(targetStatusList));
    expect(progressList, containsAllInOrder(targetProgressList));
  }
}

class HttpAdapterTestWith612 implements HttpClientAdapter {
  /// 记录 CompletePartsTask 被创建的次数
  /// 第一次我们拦截并返回 612，第二次不拦截
  bool completePartsTaskResponse612 = false;
  final HttpClientAdapter _adapter = HttpClientAdapter();
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
