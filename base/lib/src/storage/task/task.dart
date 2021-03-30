import 'dart:async';

import 'package:meta/meta.dart';
import 'package:qiniu_sdk_base/qiniu_sdk_base.dart';

export 'request_task.dart';
export 'task_manager.dart';

/// 定义一个 Task 的抽象类
///
/// 异步的任务，比如请求，批处理都可以继承这个类实现一个 Task
abstract class Task<T> {
  late TaskManager manager;

  @protected
  Completer<T> completer = Completer();

  Future<T> get future => completer.future;

  /// 创建任务的抽象方法
  Future<T> createTask();

  /// [Task] 启动之前会调用，该方法只会在第一次被 [TaskManager] 初始化的时候调用
  @mustCallSuper
  void preStart() {}

  /// [createTask] 执行之后会调用
  @mustCallSuper
  void postStart() {}

  /// 在 [createTask] 的返回值接收到结果之后调用
  @mustCallSuper
  void postReceive(T data) {
    manager.removeTask(this);
    completer.complete(data);
  }

  /// 在 [createTask] 的返回值出错之后调用
  @mustCallSuper
  void postError(Object error) {
    manager.removeTask(this);
    completer.completeError(error);
  }

  /// Task 被重启之前执行，[Task.restart] 调用后立即执行
  void preRestart() {}

  /// Task 被重启之后执行，[createTask] 被重新调用后执行
  void postRestart() {}
}
