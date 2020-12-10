import 'package:meta/meta.dart';

import '../config/config.dart';

import 'request_task.dart';
import 'task.dart';

class TaskManager {
  @protected
  final List<Task> workingTasks = [];

  final Config config;

  TaskManager({
    @required this.config,
  });

  /// 添加一个 [Task]
  ///
  /// 被添加的 [task] 会被立即执行 [createTask]
  @mustCallSuper
  void addTask(Task task) {
    workingTasks.add(task);
    task
      ..manager = this
      ..preStart();

    /// 把同步的任务改成异步，防止 [RequestTask.addStatusListener] 没有被触发
    Future.delayed(Duration(milliseconds: 0), () {
      task.createTask().then(task.postReceive).catchError(task.postError);
      task.postStart();
    });
  }

  void addRequestTask(RequestTask task) {
    task.config = config;
    addTask(task);
  }

  @mustCallSuper
  void removeTask(Task task) {
    workingTasks.remove(task);
  }

  @mustCallSuper
  void restartTask(Task task) {
    task.preRestart();
    Future.delayed(Duration(milliseconds: 0), () {
      task.createTask().then(task.postReceive).catchError(task.postError);
      task.postRestart();
    });
  }

  /// 某个任务是不是运行中
  bool isAlive(Type type) {
    final found = workingTasks.firstWhere(
        (element) => element.runtimeType == type,
        orElse: () => null);
    if (found != null) {
      return true;
    }
    return false;
  }
}
