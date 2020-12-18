import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';
import 'package:test/test.dart';

class PutControllerBuilder {
  final putController = PutController();
  final statusList = <RequestTaskStatus>[];
  double _sendPercent, _totalPercent;

  PutControllerBuilder() {
    putController
      ..addStatusListener(statusList.add)
      ..addProgressListener((percent) {
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
  void testStatus([List<RequestTaskStatus> targetStatusList]) {
    targetStatusList ??= [
      RequestTaskStatus.Init,
      RequestTaskStatus.Request,
      RequestTaskStatus.Success
    ];
    expect(statusList, equals(targetStatusList));
  }
}
