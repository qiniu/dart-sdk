part of 'request_task.dart';

class RequestTaskController
    with RequestTaskProgressListenersMixin, RequestTaskStatusListenersMixin {
  final CancelToken cancelToken = CancelToken();

  /// 是否被取消过
  bool get isCancelled => cancelToken.isCancelled;

  void cancel() {
    // 允许重复取消，但是已经取消后不会有任何行为发生
    if (isCancelled) {
      return;
    }

    cancelToken.cancel();
  }
}

typedef RequestTaskProgressListener = void Function(int sent, int total);

/// 请求进度。
///
/// 使用 client 发出去的请求才会触发，其他情况继承 RequestTask 的需要手动触发
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

  /// 初始化任务
  Init,

  /// 请求准备发出的时候触发
  Request,

  /// 请求完成后触发
  Success,

  /// 请求被取消后触发
  Cancel,

  /// 请求出错后触发
  Error,

  /// 请求出错触发重试时触发
  Retry
}

typedef RequestTaskStatusListener = void Function(RequestTaskStatus status);

/// 任务状态。
///
/// 自动触发(preStart, postReceive)
mixin RequestTaskStatusListenersMixin {
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
    status = status;
    for (final listener in _statusListeners) {
      listener(status);
    }
  }
}
