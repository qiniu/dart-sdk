part of 'request_task.dart';

class RequestTaskManager extends TaskManager {
  final Config config;

  RequestTaskManager({
    @required this.config,
  }) : assert(config != null);

  @override
  void addTask(covariant RequestTask task) {
    task.config = config;
    super.addTask(task);
  }
}
