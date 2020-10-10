import 'package:meta/meta.dart';
import 'package:qiniu_sdk_base/src/config/config.dart';

import 'abstract_request_task.dart';
import 'abstract_task.dart';

class TaskManager<T extends Task> {
  @protected
  final List<Task> workingTasks = [];

  /// 添加一个 [Task]
  ///
  /// 被添加的 [task] 会被立即执行 [createTask]
  @mustCallSuper
  T addTask(T task) {
    workingTasks.add(task);
    task.preStart();

    /// 把同步的任务改成异步，防止 [RequestTask.addStatusListener] 没有被触发
    Future.delayed(Duration(milliseconds: 0), () {
      task.createTask().then(task.postReceive).catchError(task.postError);
      task.postStart();
    });

    return task;
  }

  @mustCallSuper
  void removeTask(T task) {
    workingTasks.remove(task);
  }

  @mustCallSuper
  void restartTask(T task) {
    task.preRestart();
    Future.delayed(Duration(milliseconds: 0), () {
      task.createTask().then(task.postReceive).catchError(task.postError);
      task.postRestart();
    });
  }
}

class RequestTaskManager<T extends RequestTask> extends TaskManager<T> {
  Config config;

  RequestTaskManager({this.config});

  T addRequestTask(T task) {
    task
      ..manager = this
      ..config = config;
    return addTask(task);
  }
}
