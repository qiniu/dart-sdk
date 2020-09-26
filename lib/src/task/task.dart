import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:qiniu_sdk_base/src/config/config.dart';

import 'task_manager.dart';
import 'abstract_task.dart';

typedef ProgressListener = void Function(int sent, int total);

mixin ProgressListenersMixin {
  final List<ProgressListener> progressListeners = [];

  void listenProgress(ProgressListener listener) {
    progressListeners.add(listener);
  }

  void unlistenProgress(ProgressListener listener) {
    progressListeners.remove(listener);
  }

  void notifyProgressListeners(int sent, int total) {
    for (final listener in progressListeners) {
      listener(sent, total);
    }
  }
}

mixin CancelableTaskMixin {
  /// 取消任务
  void cancel();

  /// 恢复取消的任务，继续执行
  ///
  /// 如果当前任务没有被取消则无法恢复，建议使用 [TaskManager.restartTask]
  void resume();
}

enum RequestStatus {
  None,

  /// 请求准备发出的时候触发
  Request,

  /// 请求完成后触发
  Done,

  /// 请求被取消后触发
  Cancel,

  /// 请求出错后触发
  Error
}

typedef RequestStatusListener = void Function(RequestStatus status);

mixin RequestStatusMixin {
  @protected
  RequestStatus status = RequestStatus.None;

  final List<RequestStatusListener> _statusListeners = [];

  void addStatusListener(RequestStatusListener listener) {
    _statusListeners.add(listener);
  }

  void removeStatusListener(RequestStatus listener) {
    _statusListeners.remove(listener);
  }

  void notifyStatusListeners(RequestStatus status) {
    for (final listener in _statusListeners) {
      listener(status);
    }
  }
}

abstract class AbstractRequestTask<T> extends AbstractTask<T>
    with ProgressListenersMixin, CancelableTaskMixin, RequestStatusMixin {
  final Dio client = Dio();
  CancelToken _cancelToken = CancelToken();

  /// [RequestTaskManager.addRequestTask] 会初始化这个
  Config config;
  RequestTaskManager manager;

  void Function(T) onReceive;

  void Function(dynamic) onError;

  void Function(dynamic) onCancel;

  @mustCallSuper
  @override
  void cancel() {
    if (!_cancelToken.isCancelled) {
      _cancelToken.cancel();
    }
  }

  @mustCallSuper
  @override
  void resume() {
    if (_cancelToken.isCancelled) {
      _cancelToken = CancelToken();
      manager.restartTask(this);
    }
  }

  @override
  @mustCallSuper
  void preStart() {
    client.interceptors.add(InterceptorsWrapper(onRequest: (options) {
      status = RequestStatus.Request;
      notifyStatusListeners(status);
      options.cancelToken = _cancelToken;
      options.onSendProgress = notifyProgressListeners;

      return options;
    }));
    super.preStart();
  }

  @override
  @mustCallSuper
  void postReceive(T data) {
    status = RequestStatus.Done;
    onReceive?.call(data);
    manager.removeTask(this);
    super.postReceive(data);
  }

  /// [creatTask] 被取消后触发
  @mustCallSuper
  void postCancel(DioError error) {
    status = RequestStatus.Cancel;
    notifyStatusListeners(status);
    onCancel?.call(error);
  }

  @override
  @mustCallSuper
  void postError(error) {
    if (error is DioError && error.type == DioErrorType.CANCEL) {
      postCancel(error);
    } else {
      status = RequestStatus.Error;
      notifyStatusListeners(status);
      onError?.call(error);
    }
    super.postError(error);
  }
}
