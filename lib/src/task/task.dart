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

enum RequestStatus { None, Request, Done, Cancel, Error }

typedef RequestStatusListener = void Function(RequestStatus status);

mixin RequestStatusMixin {
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

typedef ReceiveListener<T> = void Function(T);
typedef CancelListener = void Function(DioError);
typedef ErrorListener = void Function(dynamic);

abstract class AbstractRequestTask<T> extends AbstractTask<T>
    with ProgressListenersMixin, CancelableTaskMixin, RequestStatusMixin {
  final Dio client = Dio();
  final _cancelToken = CancelToken();

  /// [RequestTaskManager.addRequestTask] 会初始化这个
  Config config;
  RequestTaskManager manager;

  final List<ReceiveListener<T>> _receiveListeners = [];

  @mustCallSuper
  void onReceive(ReceiveListener<T> listener) {
    _receiveListeners.add(listener);
  }

  final List<ErrorListener> _errorListeners = [];

  void onError(ErrorListener listener) {
    _errorListeners.add(listener);
  }

  final List<CancelListener> _cancelListeners = [];

  @mustCallSuper
  void onCancel(CancelListener listener) {
    _cancelListeners.add(listener);
  }

  /// 取消任务，子类可以覆盖此方法实现自己的逻辑
  @override
  void cancel() {
    if (status != RequestStatus.Request) {
      throw UnsupportedError(
          'cancel method can not be call before request havnt be posted. ');
    }
    if (!_cancelToken.isCancelled) {
      _cancelToken.cancel();
    }
  }

  @override
  void resume() {
    if (_cancelToken.isCancelled) {
      manager.restartTask(this);
    }
  }

  @override
  @mustCallSuper
  void preStart() {
    super.preStart();
    client.interceptors.add(InterceptorsWrapper(onRequest: (options) {
      status = RequestStatus.Request;
      notifyStatusListeners(status);
      options.cancelToken = _cancelToken;
      options.onSendProgress = notifyProgressListeners;

      return options;
    }));
  }

  @override
  @mustCallSuper
  void postReceive(T data) {
    status = RequestStatus.Done;
    for (final listener in _receiveListeners) {
      listener(data);
    }
    manager.removeTask(this);
    super.postReceive(data);
  }

  /// [creatTask] 被取消后触发
  @mustCallSuper
  void postCancel(DioError error) {
    status = RequestStatus.Cancel;
    notifyStatusListeners(status);
    for (final listener in _cancelListeners) {
      listener(error);
    }
  }

  @override
  @mustCallSuper
  void postError(error) {
    if (error is DioError && error.type == DioErrorType.CANCEL) {
      postCancel(error);
    } else {
      status = RequestStatus.Error;
      notifyStatusListeners(status);
      for (final listener in _errorListeners) {
        listener(error);
      }
    }
    super.postError(error);
  }
}
