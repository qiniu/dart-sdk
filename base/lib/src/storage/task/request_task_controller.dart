part of 'request_task.dart';

class RequestTaskController
    with
        RequestTaskProgressListenersMixin,
        RequestTaskStatusListenersMixin,
        PutTaskSendProgressListenersMixin {
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

typedef PutTaskSendProgressListener = void Function(int sent, int total);

/// 请求发送进度
///
/// 使用 Dio 发出去的请求才会触发
mixin PutTaskSendProgressListenersMixin {
  final List<PutTaskSendProgressListener> _sendProgressListeners = [];

  void Function() addSendProgressListener(
      PutTaskSendProgressListener listener) {
    _sendProgressListeners.add(listener);
    return () => removeSendProgressListener(listener);
  }

  void removeSendProgressListener(PutTaskSendProgressListener listener) {
    _sendProgressListeners.remove(listener);
  }

  void notifySendProgressListeners(int sent, int total) {
    for (final listener in _sendProgressListeners) {
      listener(sent, total);
    }
  }
}

typedef RequestTaskProgressListener = void Function(double percent);

/// 任务进度
///
/// 当前任务的总体进度，初始化占 1%，处理请求占 98%，完成占 1%，总体 100%
mixin RequestTaskProgressListenersMixin {
  final List<RequestTaskProgressListener> _progressListeners = [];

  void Function() addProgressListener(RequestTaskProgressListener listener) {
    _progressListeners.add(listener);
    return () => removeProgressListener(listener);
  }

  void removeProgressListener(RequestTaskProgressListener listener) {
    _progressListeners.remove(listener);
  }

  void notifyProgressListeners(double percent) {
    for (final listener in _progressListeners) {
      listener(percent);
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
