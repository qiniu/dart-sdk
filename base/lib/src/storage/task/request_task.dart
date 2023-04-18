import 'package:diox/diox.dart';
import 'package:meta/meta.dart';

import '../../../qiniu_sdk_base_diox.dart';

part 'request_task_controller.dart';
part 'request_task_manager.dart';

String _getUserAgent() {
  return [
    // TODO version
    'QiniuDart'
  ].join(' ');
}

abstract class RequestTask<T> extends Task<T> {
  // 准备阶段占总任务的百分比
  static double preStartTakePercentOfTotal = 0.001;
  // 处理中阶段占总任务的百分比
  static double onSendProgressTakePercentOfTotal = 0.99;
  // 完成阶段占总任务的百分比
  static double postReceiveTakePercentOfTotal = 1;

  final Dio client = Dio();

  /// [RequestTaskManager.addTask] 会初始化这个
  late final Config config;
  @override
  // ignore: overridden_fields
  covariant late final RequestTaskManager manager;
  final RequestTaskController? controller;

  // 重试次数
  int retryCount = 0;

  // 最大重试次数
  int retryLimit = 3;

  bool _isRetrying = false;
  bool get isRetrying => _isRetrying;

  RequestTask({this.controller});

  @override
  @mustCallSuper
  void preStart() {
    // 如果已经取消了，直接报错
    if (controller != null && controller!.cancelToken.isCancelled) {
      throw StorageError(type: StorageErrorType.CANCEL);
    }

    controller?.notifyStatusListeners(StorageStatus.Init);
    controller?.notifyProgressListeners(preStartTakePercentOfTotal);
    retryLimit = config.retryLimit;
    client.httpClientAdapter = config.httpClientAdapter;
    client.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      controller?.notifyStatusListeners(StorageStatus.Request);
      options
        ..cancelToken = controller?.cancelToken
        ..onSendProgress = (sent, total) => onSendProgress(sent / total);
      options.headers['User-Agent'] = _getUserAgent();

      handler.next(options);
    }));

    super.preStart();
  }

  @override
  @mustCallSuper
  void preRestart() {
    _isRetrying = retryCount <= retryLimit && retryCount > 0;
    controller?.notifyStatusListeners(StorageStatus.Retry);
    super.preRestart();
  }

  @override
  @mustCallSuper
  void postReceive(T data) {
    controller?.notifyStatusListeners(StorageStatus.Success);
    controller?.notifyProgressListeners(postReceiveTakePercentOfTotal);
    super.postReceive(data);
  }

  /// [createTask] 被取消后触发
  @mustCallSuper
  void postCancel(StorageError error) {
    controller?.notifyStatusListeners(StorageStatus.Cancel);
  }

  @override
  @mustCallSuper
  void postError(Object error) async {
    // 处理 Dio 异常
    if (error is DioError) {
      if (_checkIfNeedRetry(error)) {
        if (_isHostUnavailable(error)) {
          config.hostProvider.freezeHost(error.requestOptions.path);
        }
        if (retryCount < retryLimit) {
          retryCount++;
          // TODO 这里也许有优化空间，任务不应该自己重启自己，而应该通过消息或者报错告诉负责这个任务的管理者去重试
          manager.restartTask(this);
          return;
        }
      }

      final storageError = StorageError.fromDioError(error);

      // 通知状态
      if (error.type == DioErrorType.cancel) {
        postCancel(storageError);
      } else {
        controller?.notifyStatusListeners(StorageStatus.Error);
      }

      super.postError(storageError);
      return;
    }

    // 处理 Storage 异常。如果有子任务，错误可能被子任务加工成 StorageError
    if (error is StorageError) {
      if (error.type == StorageErrorType.CANCEL) {
        postCancel(error);
      } else {
        controller?.notifyStatusListeners(StorageStatus.Error);
      }

      super.postError(error);
      return;
    }

    // 不能处理的异常
    if (error is Error) {
      controller?.notifyStatusListeners(StorageStatus.Error);
      final storageError = StorageError.fromError(error);
      super.postError(storageError);
      return;
    }

    controller?.notifyStatusListeners(StorageStatus.Error);
    super.postError(error);
  }

  // 自定义发送进度处理逻辑
  void onSendProgress(double percent) {
    controller?.notifySendProgressListeners(percent);
    controller
        ?.notifyProgressListeners(percent * onSendProgressTakePercentOfTotal);
  }

  bool _checkIfNeedRetry(DioError error) {
    if (!_canConnectToHost(error) || _isHostUnavailable(error)) {
      return true;
    }
    if (error.type == DioErrorType.badResponse) {
      if (error.response?.statusCode == 612) {
        return true;
      }
    }
    return false;
  }

  // host 是否可以连接上
  bool _canConnectToHost(Object error) {
    if (error is DioError) {
      if (error.type == DioErrorType.badResponse) {
        final statusCode = error.response?.statusCode;
        if (statusCode is int && statusCode > 99) {
          return true;
        }
      }

      if (error.type == DioErrorType.cancel) {
        return true;
      }
    }

    return false;
  }

  // host 是否不可用
  bool _isHostUnavailable(Object error) {
    if (error is DioError) {
      if (error.type == DioErrorType.badResponse) {
        final statusCode = error.response?.statusCode;
        if (statusCode == 502) {
          return true;
        }
        if (statusCode == 503) {
          return true;
        }
        if (statusCode == 504) {
          return true;
        }
        if (statusCode == 599) {
          return true;
        }
      }
      // ignore: todo
      // TODO 更详细的信息 SocketException
    }

    return false;
  }
}
