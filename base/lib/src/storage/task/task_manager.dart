import 'dart:async';

import 'package:meta/meta.dart';

import 'task.dart';

class TaskManager {
  /// 运行中的任务表，key 为 [Task.taskID]，便于 O(1) 去重查询。
  final Map<String, Task> _workingTasks = {};

  /// 判断是否有 taskID 对应的 Task 正在运行
  bool hasTask(String taskID) {
    return _workingTasks.containsKey(taskID);
  }

  /// 添加一个 [Task]
  ///
  /// 被添加的 [task] 会被立即执行 [Task.createTask]，任务执行完会从本管理器中移除。
  ///
  /// 返回值约定（重要）：
  /// 返回的 [Future] 仅代表"任务调度生命周期"已经走完，**不应被外部 await**，
  /// 也不应被外部 `try`/`catch`。任务的实际结果与错误请通过 [Task.future] 获取：
  ///
  /// ```dart
  /// unawaited(taskManager.addTask(task));
  /// try {
  ///   final result = await task.future;
  /// } on StorageError catch (e) {
  ///   // handle
  /// }
  /// ```
  ///
  /// 之所以保留 `Future<void>` 签名而非 `void`：方法体内部需要 `await`
  /// 子调用（preStart / createTask / postReceive），改成 `void` 会让
  /// async gap 的异常进入 zone uncaughtError，丢失定位上下文。
  @mustCallSuper
  Future<void> addTask(Task task) async {
    _workingTasks[task.taskID()] = task;
    try {
      await task.preStart();
      final taskFuture = task.createTask();
      await task.postStart();

      final result = await taskFuture;
      await removeTask(task);
      await task.postReceive(result);
    } catch (error) {
      if (task.showRetry(error)) {
        await task.postError(error, complete: false);
        await restartTask(task);
      } else {
        await removeTask(task);
        await task.postError(error, complete: true);
      }
    }
  }

  @mustCallSuper
  Future<void> removeTask(Task task) async {
    _workingTasks.remove(task.taskID());
  }

  @mustCallSuper
  Future<void> restartTask(Task task) async {
    try {
      await task.preRestart();
      final taskFuture = task.createTask();
      await task.postRestart();

      final result = await taskFuture;
      await removeTask(task);
      await task.postReceive(result);
    } catch (error) {
      if (task.showRetry(error)) {
        await task.postError(error, complete: false);
        await restartTask(task);
      } else {
        await removeTask(task);
        await task.postError(error, complete: true);
      }
    }
  }

  /// 返回当前运行中的 [Task]
  List<Task<dynamic>> getTasks() {
    return _workingTasks.values.toList();
  }

  /// 查找类型符合 [T] 的 [Task]
  List<T> getTasksByType<T extends Task<dynamic>>() {
    return _workingTasks.values.whereType<T>().toList();
  }

  /// 临时跑一个独立 [Task]，不参与任何外部 [TaskManager] 的去重 / 状态查询，
  /// 仅借用 [addTask] 的生命周期调度（preStart → createTask → postReceive 等）。
  ///
  /// 内部用一次性 [TaskManager] 实例承载，返回 task 的最终结果。
  /// 适用于子任务从父任务内部派发、不需要对外可查询的场景。
  static Future<R> runStandalone<R>(Task<R> task) {
    final mgr = TaskManager();
    unawaited(mgr.addTask(task));
    return task.future;
  }
}
