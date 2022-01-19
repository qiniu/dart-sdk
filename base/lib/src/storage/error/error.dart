import 'package:dio/dio.dart';
import 'package:qiniu_sdk_base/src/error/error.dart';

enum StorageErrorType {
  /// 连接超时
  CONNECT_TIMEOUT,

  /// 发送超时
  SEND_TIMEOUT,

  /// 接收超时
  RECEIVE_TIMEOUT,

  /// 服务端响应了但是状态码是 400 以上
  RESPONSE,

  /// 请求被取消
  CANCEL,

  /// 没有可用的服务器
  NO_AVAILABLE_HOST,

  /// 已在处理队列中
  IN_PROGRESS,

  /// 未知或者不能处理的错误
  UNKNOWN,
}

class StorageError extends QiniuError {
  /// [type] 不是 [StorageErrorType.RESPONSE] 的时候为 null
  final int? code;
  final StorageErrorType type;

  StorageError({
    required this.type,
    this.code,
    dynamic rawError,
    String? message,
  }) : super(rawError: rawError, message: message);

  factory StorageError.fromError(Error error) {
    return StorageError(
        type: StorageErrorType.UNKNOWN,
        rawError: error,
        message: error.toString());
  }

  factory StorageError.fromDioError(DioError error) {
    return StorageError(
      type: _mapDioErrorType(error.type),
      code: error.response?.statusCode,
      message: error.response?.data.toString() ?? error.message,
      rawError: error.error,
    );
  }

  @override
  String toString() {
    var msg = 'StorageError [$type, $code]: $message';
    msg += '\n$stackTrace';
    return msg;
  }
}

StorageErrorType _mapDioErrorType(DioErrorType type) {
  switch (type) {
    case DioErrorType.connectTimeout:
      return StorageErrorType.CONNECT_TIMEOUT;
    case DioErrorType.sendTimeout:
      return StorageErrorType.SEND_TIMEOUT;
    case DioErrorType.receiveTimeout:
      return StorageErrorType.RECEIVE_TIMEOUT;
    case DioErrorType.response:
      return StorageErrorType.RESPONSE;
    case DioErrorType.cancel:
      return StorageErrorType.CANCEL;
    case DioErrorType.other:
    default:
      return StorageErrorType.UNKNOWN;
  }
}
