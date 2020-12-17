import 'package:meta/meta.dart';

import '../config/config.dart';

import 'request_task.dart';
import 'task.dart';

class TaskManager {
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
    try {
      task
        ..manager = this
        ..preStart();
    } catch (e) {
      rethrow;
    }

    // 把同步的任务改成异步，防止 [RequestTask.addStatusListener] 没有被触发
    Future.delayed(Duration(milliseconds: 0), () {
      workingTasks.add(task);
      task.createTask().then(task.postReceive).catchError(task.postError);
      try {
        task.postStart();
      } catch (e) {
        removeTask(task);
        rethrow;
      }
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
    try {
      task.preRestart();
    } catch (e) {
      removeTask(task);
      rethrow;
    }
    Future.delayed(Duration(milliseconds: 0), () {
      task.createTask().then(task.postReceive).catchError(task.postError);
      try {
        task.postRestart();
      } catch (e) {
        removeTask(task);
        rethrow;
      }
    });
  }

  /// 返回当前运行中的 [Task]
  List<Task<dynamic>> getTasks() {
    return workingTasks;
  }

  /// 查找类型符合 [T] 的 [Task]
  List<T> getTasksByType<T extends Task<dynamic>>() {
    return workingTasks.whereType<T>().toList();
  }

  /// 某个任务是不是运行中
  bool isAlive(Task task) {
    final found = workingTasks.firstWhere(
        (element) => element.runtimeType == task.runtimeType,
        orElse: () => null);
    if (found != null) {
      return true;
    }
    return false;
  }
}
