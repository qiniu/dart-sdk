import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';
import 'package:test/test.dart';

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
