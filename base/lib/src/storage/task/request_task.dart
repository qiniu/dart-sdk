import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:qiniu_sdk_base/src/storage/error/error.dart';

import '../config/config.dart';

import 'task.dart';

part 'request_task_controller.dart';

abstract class RequestTask<T> extends Task<T> {
  final Dio client = Dio();

  /// [RequestTaskManager.addRequestTask] 会初始化这个
  Config config;
  RequestTaskController controller;

  /// 重试次数
  int _retryCount = 0;

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
    super.postReceive(data);
  }

  /// [createTask] 被取消后触发
  @mustCallSuper
  void postCancel(StorageError error) {
    controller?.notifyStatusListeners(RequestTaskStatus.Cancel);
  }

  @override
  @mustCallSuper
  void postError(Object error) async {
    // 重试和冻结
    if (error is DioError) {
      if (!canConnectToHost(error)) {
        // host 连不上，判断是否 host 不可用造成的, 比如 tls error(没做还)
        if (isHostUnavailable(error)) {
          config.hostProvider.freezeHost(error.request.path);
        }

        // 继续尝试当前 host，如果是服务器坏了则切换到其他 host
        if (_retryCount < config.retryLimit) {
          _retryCount++;
          manager.restartTask(this);
          return;
        }
      }

      // 能连上但是服务器不可用，比如 502
      if (isHostUnavailable(error)) {
        config.hostProvider.freezeHost(error.request.path);

        // 切换到其他 host
        if (_retryCount < config.retryLimit) {
          _retryCount++;
          manager.restartTask(this);
          return;
        }
      }

      if (error.type != DioErrorType.DEFAULT) {
        final storageError = StorageError.fromDioError(error);

        // 通知状态
        if (error.type == DioErrorType.CANCEL) {
          postCancel(storageError);
        } else {
          controller?.notifyStatusListeners(RequestTaskStatus.Error);
        }

        super.postError(storageError);
        return;
      }
    }
    // 如果有子任务，错误可能被子任务加工成 StorageError
    if (error is StorageError) {
      if (error.type == StorageErrorType.CANCEL) {
        postCancel(error);
      } else {
        controller?.notifyStatusListeners(RequestTaskStatus.Error);
      }
    }

    super.postError(error);
  }

  // host 是否可以连接上
  bool canConnectToHost(Object error) {
    if (error is DioError) {
      if (error.type == DioErrorType.RESPONSE &&
          error.response.statusCode > 99) {
        return true;
      }

      if (error.type == DioErrorType.CANCEL) {
        return true;
      }
    }

    return false;
  }

  // host 是否不可用
  bool isHostUnavailable(Object error) {
    if (error is DioError) {
      if (error.type == DioErrorType.RESPONSE) {
        final statusCode = error.response.statusCode;
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
