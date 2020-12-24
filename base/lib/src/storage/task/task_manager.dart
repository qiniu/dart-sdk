import 'package:meta/meta.dart';

import 'task.dart';

class TaskManager {
  final List<Task> workingTasks = [];

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

    workingTasks.add(task);
    task.createTask().then(task.postReceive).catchError(task.postError);

    try {
      task.postStart();
    } catch (e) {
      removeTask(task);
      rethrow;
    }
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

    task.createTask().then(task.postReceive).catchError(task.postError);

    try {
      task.postRestart();
    } catch (e) {
      removeTask(task);
      rethrow;
    }
  }

  /// 返回当前运行中的 [Task]
  List<Task<dynamic>> getTasks() {
    return workingTasks;
  }

  /// 查找类型符合 [T] 的 [Task]
  List<T> getTasksByType<T extends Task<dynamic>>() {
    return workingTasks.whereType<T>().toList();
  }
}
