import 'dart:async';

import 'package:meta/meta.dart';

export 'request_task.dart';
export 'request_task_controller.dart';
export 'task_manager.dart';

/// 定义一个 Task 的抽象类
///
/// 异步的任务，比如请求，批处理都可以继承这个类实现一个 Task
abstract class Task<T> {
  @protected
  Completer<T> completer = Completer();

  Future<T> get future => completer.future;

  /// 创建任务的抽象方法
  Future<T> createTask();

  String taskID() {
    return hashCode.toString();
  }

  /// [Task] 启动之前会调用，该方法只会在第一次被 [TaskManager] 初始化的时候调用
  @mustCallSuper
  Future<void> preStart() async {}

  /// [createTask] 执行之后会调用
  @mustCallSuper
  Future<void> postStart() async {}

  /// 在 [createTask] 的返回值接收到结果之后调用
  @mustCallSuper
  Future<void> postReceive(T data) async {
    completer.complete(data);
  }

  /// 在 [createTask] 的返回值出错之后调用
  @mustCallSuper
  Future<void> postError(Object error, {bool complete = true}) async {
    if (complete) {
      completer.completeError(error);
    }
  }

  /// 是否需要重试，默认不重试
  bool showRetry(Object error) {
    return false;
  }

  /// Task 被重启之前执行，[Task.restart] 调用后立即执行
  Future<void> preRestart() async {}

  /// Task 被重启之后执行，[createTask] 被重新调用后执行
  Future<void> postRestart() async {}
}
