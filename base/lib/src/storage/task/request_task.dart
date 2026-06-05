import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'task.dart';
import '../../../qiniu_sdk_base.dart';
import '../../util/user_agent/user_agent.dart';

abstract class RequestTask<T> extends Task<T> {
  // 准备阶段占总任务的百分比
  static double preStartTakePercentOfTotal = 0.001;
  // 处理中阶段占总任务的百分比
  static double onSendProgressTakePercentOfTotal = 0.99;
  // 完成阶段占总任务的百分比
  static double postReceiveTakePercentOfTotal = 1;

  final Dio client = Dio();

  /// 配置项
  Config _config;

  @protected
  Config get config => _config;

  /// 任务控制器，可以用于取消任务、获取上述的状态，进度等信息
  final RequestTaskController? controller;

  // 重试次数
  int retryCount = 0;

  // 最大重试次数
  int retryLimit = 2;

  Object? _lastError;

  RequestTask(this._config, {this.controller});

  @override
  @mustCallSuper
  Future<void> preStart() async {
    // 如果已经取消了，直接报错
    if (controller != null && controller!.cancelToken.isCancelled) {
      throw StorageError(type: StorageErrorType.CANCEL);
    }

    /// 需要先计算 UA，因为后续 _config 会被重新赋值，否则 UA 外部配置的 UA
    var userAgent = getDefaultUserAgent();
    final appUserAgent = await config.appUserAgent;
    if (appUserAgent != '') {
      userAgent += ' $appUserAgent';
    }

    _config = config.copyWith(
      hostProvider: _HostProvider(config.hostProvider),
    );

    controller?.notifyStatusListeners(StorageStatus.Init);
    controller?.notifyProgressListeners(preStartTakePercentOfTotal);
    retryLimit = _config.retryLimit;
    client.httpClientAdapter = _config.httpClientAdapter;
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

    await super.preStart();
  }

  @override
  @mustCallSuper
  Future<void> preRestart() async {
    retryCount++;
    controller?.notifyStatusListeners(StorageStatus.Retry);
    await super.preRestart();
  }

  @override
  @mustCallSuper
  Future<void> postReceive(T data) async {
    controller?.notifyStatusListeners(StorageStatus.Success);
    controller?.notifyProgressListeners(postReceiveTakePercentOfTotal);
    await super.postReceive(data);
  }

  /// [createTask] 被取消后触发
  @mustCallSuper
  Future<void> postCancel(StorageError error) async {
    controller?.notifyStatusListeners(StorageStatus.Cancel);
  }

  @override
  @mustCallSuper
  Future<void> postError(Object error, {bool complete = false}) async {
    Object postError = error;
    StorageStatus newStatus = StorageStatus.Error;

    if (error is DioException) {
      /// 处理 Dio 异常
      if (_isHostUnavailable(error)) {
        config.hostProvider.freezeHost(error.requestOptions.path);
      }

      postError = StorageError.fromDioError(error);

      /// 通知状态
      if (error.type == DioExceptionType.cancel) {
        newStatus = StorageStatus.Cancel;
      }
    } else if (error is StorageError) {
      /// 处理 Storage 异常。如果有子任务，错误可能被子任务加工成 StorageError
      if (error.type == StorageErrorType.CANCEL) {
        newStatus = StorageStatus.Cancel;
      }

      /// 这个错误不应该被外界感知到
      if (error.type == StorageErrorType.NO_AVAILABLE_HOST) {
        if (_lastError != null) {
          postError = _lastError!;
        }
        // 避免上层重试
        retryCount = retryLimit;
      }
    } else if (error is Error) {
      // 不能处理的异常
      postError = StorageError.fromError(error);
    }

    if (complete) {
      /// 整个任务完全结束后才会更新任务错误状态
      controller?.notifyStatusListeners(newStatus);
    }

    _lastError = postError;
    await super.postError(postError, complete: complete);
  }

  // 自定义发送进度处理逻辑
  void onSendProgress(double percent) {
    controller?.notifySendProgressListeners(percent);
    controller
        ?.notifyProgressListeners(percent * onSendProgressTakePercentOfTotal);
  }

  @override
  bool showRetry(Object error) {
    if (error is! DioException) {
      return false;
    }
    if (!isHostRetryableError(error)) {
      return false;
    }
    return retryCount < retryLimit;
  }

  @protected
  bool isHostRetryableError(DioException error) {
    if (!_canConnectToHost(error) || _isHostUnavailable(error)) {
      return true;
    }
    if (error.type != DioExceptionType.badResponse) {
      return false;
    }
    return _isRetryableResponseCode(error.response?.statusCode);
  }

  @protected
  bool isRegionRetryableError(StorageError error) {
    if (_isRetryableResponseCode(error.code)) {
      return true;
    }
    // upload context 过期
    if (isCtxExpiedError(error.code)) {
      return true;
    }
    // 连接级别的错误（无状态码），可能是区域级故障
    if (error.code == null &&
        (error.type == StorageErrorType.CONNECT_TIMEOUT ||
            error.type == StorageErrorType.SEND_TIMEOUT ||
            error.type == StorageErrorType.RECEIVE_TIMEOUT)) {
      return true;
    }
    return false;
  }

  @protected
  bool isCtxExpiedError(int? statusCode) {
    return statusCode == 701 || statusCode == 612;
  }

  bool _isRetryableResponseCode(int? code) {
    // 只有 5xx 可以重试
    final statusCode = code ?? 0;
    return statusCode ~/ 100 == 5 && statusCode != 573 && statusCode != 579;
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

/// HostProvider 的包装类，提供首次请求失败时的重试逻辑
///
/// 当第一次获取上传域名时，如果所有域名都被冻结导致失败，
/// 此包装器会自动解冻一个域名并重试一次。
class _HostProvider extends HostProvider {
  final HostProvider _hostprovider;

  bool _hasGetUpHost = false;

  _HostProvider(this._hostprovider);

  @override
  Future<String> getUpHost({
    required String accessKey,
    required String bucket,
    bool accelerateUploading = false,
    bool transregional = false,
    int regionIndex = 0,
  }) async {
    var retryCount = 0;
    while (true) {
      try {
        final host = await _hostprovider.getUpHost(
          accessKey: accessKey,
          bucket: bucket,
          accelerateUploading: accelerateUploading,
          transregional: transregional,
          regionIndex: regionIndex,
        );
        _hasGetUpHost = true;
        return host;
      } on StorageError catch (error) {
        if (_hasGetUpHost) {
          rethrow;
        }
        if (error.type != StorageErrorType.NO_AVAILABLE_HOST) {
          rethrow;
        }
        if (retryCount >= 3) {
          rethrow;
        }
        // 如果第一次获取上传域名就失败，尝试解冻一个上传域名后重试一次
        _hostprovider.unfreezeOne();
        retryCount++;
      }
    }
  }

  @override
  void freezeHost(String host) {
    _hostprovider.freezeHost(host);
  }

  @override
  bool isFrozen(String host) {
    return _hostprovider.isFrozen(host);
  }

  @override
  void unfreezeOne() {
    _hostprovider.unfreezeOne();
  }
}
