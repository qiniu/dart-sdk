part of 'request_task.dart';

class RequestTaskManager extends TaskManager {
  final Config config;

  RequestTaskManager({
    @required this.config,
  }) : assert(config != null);

  void addRequestTask(RequestTask task) {
    task.config = config;
    addTask(task);
  }
}
