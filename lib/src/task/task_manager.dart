import 'package:qiniu_sdk_base/src/config.dart';
import 'package:qiniu_sdk_base/src/task/task.dart';

class RequestTaskManager {
  final List<AbstractRequestTask> tasks = [];

  final RequestTaskConfig config;

  RequestTaskManager(
      {RegionProvider regionProvider, String token, Protocol upprotocol})
      : config = RequestTaskConfig(
            regionProvider: regionProvider,
            token: token,
            upprotocol: upprotocol);

  T addTask<T extends AbstractRequestTask>(T task) {
    tasks.add(task);
    task.config = config;
    task.preStart();
    task.request = task.createRequest();

    return task;
  }

  void cancel() {}
}
