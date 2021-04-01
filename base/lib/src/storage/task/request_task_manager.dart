part of 'request_task.dart';

class RequestTaskManager extends TaskManager {
  final Config config;

  RequestTaskManager({
    required this.config,
  });

  @override
  void addTask(covariant RequestTask task) {
    task.config = config;
    super.addTask(task);
  }
}
