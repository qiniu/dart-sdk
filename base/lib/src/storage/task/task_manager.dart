import 'package:meta/meta.dart';

import 'task.dart';

class TaskManager {
  final List<Task> workingTasks = [];

  /// 添加一个 [Task]
  ///
  /// 被添加的 [task] 会被立即执行 [createTask]
  @mustCallSuper
  void addTask(Task task) async {
    try {
      task
        ..manager = this
        ..preStart();
    } catch (e) {
      task.postError(e);
      return;
    }

    workingTasks.add(task);

    try {
      task.postReceive(await task.createTask());
    } catch (error) {
      task.postError(error);
      return;
    }

    try {
      task.postStart();
    } catch (e) {
      task.postError(e);
      return;
    }
  }

  @mustCallSuper
  void removeTask(Task task) {
    workingTasks.remove(task);
  }

  @mustCallSuper
  void restartTask(Task task) async {
    try {
      task.preRestart();
    } catch (e) {
      task.postError(e);
      return;
    }

    try {
      task.postReceive(await task.createTask());
    } catch (error) {
      task.postError(error);
      return;
    }

    try {
      task.postRestart();
    } catch (e) {
      task.postError(e);
      return;
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
