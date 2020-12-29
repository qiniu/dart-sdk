part of 'request_task.dart';

class RequestTaskController
    with
        RequestTaskProgressListenersMixin,
        StorageStatusListenersMixin,
        RequestTaskSendProgressListenersMixin {
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

typedef RequestTaskSendProgressListener = void Function(double percent);

/// 请求发送进度
///
/// 使用 Dio 发出去的请求才会触发
mixin RequestTaskSendProgressListenersMixin {
  final List<RequestTaskSendProgressListener> _sendProgressListeners = [];

  void Function() addSendProgressListener(
      RequestTaskSendProgressListener listener) {
    _sendProgressListeners.add(listener);
    return () => removeSendProgressListener(listener);
  }

  void removeSendProgressListener(RequestTaskSendProgressListener listener) {
    _sendProgressListeners.remove(listener);
  }

  void notifySendProgressListeners(double percent) {
    for (final listener in _sendProgressListeners) {
      listener(percent);
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

typedef StorageStatusListener = void Function(StorageStatus status);

/// 任务状态。
///
/// 自动触发(preStart, postReceive)
mixin StorageStatusListenersMixin {
  StorageStatus status = StorageStatus.None;

  final List<StorageStatusListener> _statusListeners = [];

  void Function() addStatusListener(StorageStatusListener listener) {
    _statusListeners.add(listener);
    return () => removeStatusListener(listener);
  }

  void removeStatusListener(StorageStatusListener listener) {
    _statusListeners.remove(listener);
  }

  void notifyStatusListeners(StorageStatus status) {
    status = status;
    for (final listener in _statusListeners) {
      listener(status);
    }
  }
}
