import 'package:meta/meta.dart';

import '../config/config.dart';

import 'request_task.dart';
import 'task.dart';

class TaskManager<T extends Task<dynamic>> {
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

class RequestTaskManager<T extends RequestTask<dynamic>>
    extends TaskManager<T> {
  final Config config;

  RequestTaskManager({
    @required this.config,
  });

  @override
  T addTask(T task) {
    task
      ..manager = this
      ..config = config;
    return super.addTask(task);
  }
}
