import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import '../status/status.dart';

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

  /// 重置两个进度 mixin 的单调钳制基线。
  ///
  /// 仅在每个顶层任务 preStart() 时调用一次，保证 Controller 被复用发起
  /// 第二次上传时进度回调不会被 `percent <= _lastNotified...` 过滤掉。
  /// 内部 retry（preRestart）不得调用，以保持对外进度单调性。
  @internal
  void resetProgressBaseline() {
    resetSendProgress();
    resetProgress();
  }
}

typedef RequestTaskSendProgressListener = void Function(double percent);

/// 请求发送进度
///
/// 使用 Dio 发出去的请求才会触发
mixin RequestTaskSendProgressListenersMixin {
  final List<RequestTaskSendProgressListener> _sendProgressListeners = [];

  /// 上次实际派发给监听者的发送进度。
  ///
  /// 用作单调钳制基线：只有传入的 percent 严格大于该值才向外通知，
  /// 否则视为"进度未推进"忽略。这样可以从 Controller 出口处统一屏蔽
  /// 由于 retry 等原因导致的进度回退（dio 每次 retry 都会从 0 重新累计），
  /// 保证外部观察到的进度单调不降。
  ///
  /// 如果 Controller 被复用跑第二轮上传，需要调用 [resetSendProgress] 显式归零。
  double _lastNotifiedSendProgress = 0;

  void Function() addSendProgressListener(
    RequestTaskSendProgressListener listener,
  ) {
    _sendProgressListeners.add(listener);
    return () => removeSendProgressListener(listener);
  }

  void removeSendProgressListener(RequestTaskSendProgressListener listener) {
    _sendProgressListeners.remove(listener);
  }

  void notifySendProgressListeners(double percent) {
    if (percent <= _lastNotifiedSendProgress) return;
    _lastNotifiedSendProgress = percent;
    for (final listener in _sendProgressListeners) {
      listener(percent);
    }
  }

  /// 清空发送进度的单调钳制基线。
  ///
  /// 仅在 Controller 复用、需要重新跑一轮发送时调用；
  /// 单次任务（含内部 retry）不应调用，否则单调性失效。
  @internal
  void resetSendProgress() {
    _lastNotifiedSendProgress = 0;
  }
}

typedef RequestTaskProgressListener = void Function(double percent);

/// 任务进度
///
/// 当前任务的总体进度，初始化占 1%，处理请求占 98%，完成占 1%，总体 100%
mixin RequestTaskProgressListenersMixin {
  final List<RequestTaskProgressListener> _progressListeners = [];

  /// 上次实际派发给监听者的总体进度。语义同
  /// [RequestTaskSendProgressListenersMixin._lastNotifiedSendProgress]，
  /// 用作单调钳制基线屏蔽 retry 导致的回退。
  double _lastNotifiedProgress = 0;

  void Function() addProgressListener(RequestTaskProgressListener listener) {
    _progressListeners.add(listener);
    return () => removeProgressListener(listener);
  }

  void removeProgressListener(RequestTaskProgressListener listener) {
    _progressListeners.remove(listener);
  }

  void notifyProgressListeners(double percent) {
    if (percent <= _lastNotifiedProgress) return;
    _lastNotifiedProgress = percent;
    for (final listener in _progressListeners) {
      listener(percent);
    }
  }

  /// 清空总体进度的单调钳制基线。详见 [RequestTaskSendProgressListenersMixin.resetSendProgress]。
  @internal
  void resetProgress() {
    _lastNotifiedProgress = 0;
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
    this.status = status;
    for (final listener in _statusListeners) {
      listener(status);
    }
  }
}
