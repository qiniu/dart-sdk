import 'package:dio/dio.dart';
import 'package:qiniu_sdk_base/src/error/error.dart';

// same as DioErrorType
enum StorageErrorType {
  /// 连接超时
  CONNECT_TIMEOUT,

  /// 发送超时
  SEND_TIMEOUT,

  /// 接受超时
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
  final int code;
  final StorageErrorType type;

  StorageError({this.type, this.code, String message}) : super(message);

  factory StorageError.fromDioError(DioError error) {
    return StorageError(
      type: _mapDioErrorType(error.type),
      code: error.response?.statusCode,
      message: error.response?.data.toString(),
    );
  }

  @override
  String toString() {
    var msg = 'StorageError [$type, $code]: $message';
    msg += '\n${StackTrace.current}';
    return msg;
  }
}

StorageErrorType _mapDioErrorType(DioErrorType type) {
  switch (type) {
    case DioErrorType.CONNECT_TIMEOUT:
      return StorageErrorType.CONNECT_TIMEOUT;
    case DioErrorType.SEND_TIMEOUT:
      return StorageErrorType.SEND_TIMEOUT;
    case DioErrorType.RECEIVE_TIMEOUT:
      return StorageErrorType.RECEIVE_TIMEOUT;
    case DioErrorType.RESPONSE:
      return StorageErrorType.RESPONSE;
    case DioErrorType.CANCEL:
      return StorageErrorType.CANCEL;
    case DioErrorType.DEFAULT:
    default:
      return StorageErrorType.UNKNOWN;
  }
}
