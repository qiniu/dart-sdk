import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import '../config/config.dart';

import 'task.dart';
import 'task_manager.dart';

typedef RequestTaskProgressListener = void Function(int sent, int total);

mixin RequestTaskProgressListenersMixin {
  final List<RequestTaskProgressListener> progressListeners = [];

  void Function() addProgressListener(RequestTaskProgressListener listener) {
    progressListeners.add(listener);
    return () => removeProgressListener(listener);
  }

  void removeProgressListener(RequestTaskProgressListener listener) {
    progressListeners.remove(listener);
  }

  void notifyProgressListeners(int sent, int total) {
    for (final listener in progressListeners) {
      listener(sent, total);
    }
  }
}

enum RequestTaskStatus {
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

typedef RequestTaskStatusListener = void Function(RequestTaskStatus status);

mixin RequestTaskStatusListenersMixin {
  @protected
  RequestTaskStatus status = RequestTaskStatus.None;

  final List<RequestTaskStatusListener> _statusListeners = [];

  void Function() addStatusListener(RequestTaskStatusListener listener) {
    _statusListeners.add(listener);
    return () => removeStatusListener(listener);
  }

  void removeStatusListener(RequestTaskStatusListener listener) {
    _statusListeners.remove(listener);
  }

  void notifyStatusListeners(RequestTaskStatus status) {
    for (final listener in _statusListeners) {
      listener(status);
    }
  }
}

abstract class RequestTask<T> extends Task<T>
    with RequestTaskProgressListenersMixin, RequestTaskStatusListenersMixin {
  final Dio client = Dio();
  final CancelToken _cancelToken = CancelToken();

  /// [RequestTaskManager.addRequestTask] 会初始化这个
  Config config;
  RequestTaskManager manager;

  @mustCallSuper
  void cancel() {
    if (_cancelToken.isCancelled) {
      throw UnsupportedError('$this has been canceled.');
    }

    _cancelToken.cancel();
  }

  @override
  @mustCallSuper
  void preStart() {
    status = RequestTaskStatus.Request;
    notifyStatusListeners(status);
    client.httpClientAdapter = config.httpClientAdapter;
    client.interceptors.add(InterceptorsWrapper(onRequest: (options) {
      options
        ..cancelToken = _cancelToken
        ..onSendProgress = notifyProgressListeners;

      return options;
    }));
    super.preStart();
  }

  @override
  @mustCallSuper
  void postReceive(T data) {
    status = RequestTaskStatus.Done;
    notifyStatusListeners(status);
    manager.removeTask(this);
    super.postReceive(data);
  }

  /// [createTask] 被取消后触发
  @mustCallSuper
  void postCancel(DioError error) {
    status = RequestTaskStatus.Cancel;
    notifyStatusListeners(status);
  }

  @override
  @mustCallSuper
  void postError(Object error) {
    if (error is DioError && error.type == DioErrorType.CANCEL) {
      postCancel(error);
    } else {
      status = RequestTaskStatus.Error;
      notifyStatusListeners(status);
    }

    super.postError(error);
  }
}
