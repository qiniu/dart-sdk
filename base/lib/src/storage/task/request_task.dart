import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:system_info2/system_info2.dart';
import 'package:platform_info/platform_info.dart';
import '../../../qiniu_sdk_base.dart';
import 'dart:js' as js;
part 'request_task_controller.dart';
part 'request_task_manager.dart';

// 这个函数无论如何都不应该抛出异常，即使内部依赖的第三方库不支持目标运行平台
String _getDefaultUserAgent() {
  final components = <String>['QiniuDart/v$currentVersion'];

  try {
    platform.when(
      web: () {
        components.add('Web');
        try {
          final browserUserAgent =
              js.context['navigator']['userAgent']?.toString();
          if (browserUserAgent != null) {
            components.add(browserUserAgent);
          }
        } catch (e) {
          components.add('UnknownBrowserUA');
        }
      },
      iOS: () {
        components.add('iOS');
      },
      orElse: () {
        // SystemInfo2 只支持android/linux/macos/windows
        components.addAll([
          '(${SysInfo.kernelName}; ${SysInfo.kernelVersion}; ${SysInfo.kernelArchitecture})',
          '(${SysInfo.operatingSystemName}; ${SysInfo.operatingSystemVersion})',
        ]);
      },
    );
  } catch (e) {
    // 其他任何报错
    components.add('UnknownPlatform');
  }

  // 有的操作系统（如Windows）名称可能会返回中文，这里把所有非ascii字符都过滤掉，防止设置User-Agent时产生报错
  return String.fromCharCodes(
    components.join(' ').runes.where((r) => r <= 127),
  );
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
  int retryLimit = 10;

  bool _isRetrying = false;
  bool get isRetrying => _isRetrying;

  RequestTask({this.controller});

  @override
  @mustCallSuper
  void preStart() async {
    // 如果已经取消了，直接报错
    if (controller != null && controller!.cancelToken.isCancelled) {
      throw StorageError(type: StorageErrorType.CANCEL);
    }

    controller?.notifyStatusListeners(StorageStatus.Init);
    controller?.notifyProgressListeners(preStartTakePercentOfTotal);
    retryLimit = config.retryLimit;
    client.httpClientAdapter = config.httpClientAdapter;
    var userAgent = _getDefaultUserAgent();
    final appUserAgent = await config.appUserAgent;
    if (appUserAgent != '') {
      userAgent += ' $appUserAgent';
    }
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          controller?.notifyStatusListeners(StorageStatus.Request);
          options
            ..cancelToken = controller?.cancelToken
            ..onSendProgress = (sent, total) => onSendProgress(sent / total);
          options.headers['User-Agent'] = userAgent;

          if (options.contentType == null) {
            if (options.data is Stream) {
              options.contentType = 'application/octet-stream';
            } else {
              options.contentType = 'application/json';
            }
          }

          handler.next(options);
        },
      ),
    );

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
    if (error is DioException) {
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
      if (error.type == DioExceptionType.cancel) {
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

  bool _checkIfNeedRetry(DioException error) {
    if (!_canConnectToHost(error) || _isHostUnavailable(error)) {
      return true;
    }
    if (error.type == DioExceptionType.badResponse) {
      if (error.response?.statusCode == 612) {
        return true;
      }
    }
    return false;
  }

  // host 是否可以连接上
  bool _canConnectToHost(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.badResponse) {
        final statusCode = error.response?.statusCode;
        if (statusCode is int && statusCode > 99) {
          return true;
        }
      }

      if (error.type == DioExceptionType.cancel) {
        return true;
      }
    }

    return false;
  }

  // host 是否不可用
  bool _isHostUnavailable(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          switch (statusCode) {
            case 502 || 503 || 504 || 599:
              return true;
            default:
            // do nothing
          }
        case DioExceptionType.connectionError ||
              DioExceptionType.connectionTimeout ||
              DioExceptionType.badCertificate:
          return true;
        default:
        // do nothing
      }
    }

    return false;
  }

  void checkResponse(Response response) {
    if (response.headers['x-reqid'] == null &&
        response.headers['x-log'] == null) {
      throw DioException.connectionError(
        requestOptions: response.requestOptions,
        reason: 'response might be malicious',
      );
    }
  }
}
