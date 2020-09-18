import 'package:qiniu_sdk_base/src/task/task.dart';

class RequestTaskManager {
  final List<AbstractRequestTask> tasks = [];

  addTask(AbstractRequestTask task) {
    tasks.add(task);
    task.preStart();
  }
}
