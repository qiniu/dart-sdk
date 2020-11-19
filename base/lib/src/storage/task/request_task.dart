import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import '../config/config.dart';

import 'task.dart';

part 'request_task_controller.dart';

abstract class RequestTask<T> extends Task<T> {
  final Dio client = Dio();

  /// [RequestTaskManager.addRequestTask] 会初始化这个
  Config config;
  RequestTaskController controller;

  RequestTask({this.controller});

  @override
  @mustCallSuper
  void preStart() {
    controller?.notifyStatusListeners(RequestTaskStatus.Init);
    client.httpClientAdapter = config.httpClientAdapter;
    client.interceptors.add(InterceptorsWrapper(onRequest: (options) {
      controller?.notifyStatusListeners(RequestTaskStatus.Request);
      options
        ..cancelToken = controller?.cancelToken
        ..onSendProgress = controller?.notifyProgressListeners;

      return options;
    }));
    super.preStart();
  }

  @override
  @mustCallSuper
  void postReceive(T data) {
    controller?.notifyStatusListeners(RequestTaskStatus.Success);
    manager.removeTask(this);
    super.postReceive(data);
  }

  /// [createTask] 被取消后触发
  @mustCallSuper
  void postCancel(DioError error) {
    controller?.notifyStatusListeners(RequestTaskStatus.Cancel);
  }

  @override
  @mustCallSuper
  void postError(Object error) {
    if (error is DioError && error.type == DioErrorType.CANCEL) {
      postCancel(error);
    } else {
      controller?.notifyStatusListeners(RequestTaskStatus.Error);
    }

    super.postError(error);
  }
}
