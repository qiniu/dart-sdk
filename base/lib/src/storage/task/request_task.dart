import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import '../config/config.dart';

import 'task.dart';
import 'task_manager.dart';

typedef ProgressListener = void Function(int sent, int total);

mixin ProgressListenersMixin {
  final List<ProgressListener> progressListeners = [];

  void Function() addProgressListener(ProgressListener listener) {
    progressListeners.add(listener);
    return () => removeProgressListener(listener);
  }

  void removeProgressListener(ProgressListener listener) {
    progressListeners.remove(listener);
  }

  void notifyProgressListeners(int sent, int total) {
    for (final listener in progressListeners) {
      listener(sent, total);
    }
  }
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

  void Function() addStatusListener(RequestStatusListener listener) {
    _statusListeners.add(listener);
    return () => removeStatusListener(listener);
  }

  void removeStatusListener(RequestStatusListener listener) {
    _statusListeners.remove(listener);
  }

  void notifyStatusListeners(RequestStatus status) {
    for (final listener in _statusListeners) {
      listener(status);
    }
  }
}

abstract class RequestTask<T> extends Task<T>
    with ProgressListenersMixin, RequestStatusMixin {
  final Dio client = Dio();
  final CancelToken _cancelToken = CancelToken();

  /// [RequestTaskManager.addRequestTask] 会初始化这个
  late final Config config;
  late final RequestTaskManager manager;

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
    client.httpClientAdapter = config.httpClientAdapter;
    client.interceptors.add(InterceptorsWrapper(onRequest: (options) {
      status = RequestStatus.Request;
      notifyStatusListeners(status);
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
    status = RequestStatus.Done;
    notifyStatusListeners(status);
    manager.removeTask(this);
    super.postReceive(data);
  }

  /// [createTask] 被取消后触发
  @mustCallSuper
  void postCancel(DioError error) {
    status = RequestStatus.Cancel;
    notifyStatusListeners(status);
  }

  @override
  @mustCallSuper
  void postError(Object error) {
    if (error is DioError && error.type == DioErrorType.CANCEL) {
      postCancel(error);
    } else {
      status = RequestStatus.Error;
      notifyStatusListeners(status);
    }

    super.postError(error);
  }
}
