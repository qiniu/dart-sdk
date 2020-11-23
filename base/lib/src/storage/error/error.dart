import 'package:dio/dio.dart';
import 'package:qiniu_sdk_base/src/error/error.dart';

// same as DioErrorType
enum StorageErrorType {
  /// It occurs when url is opened timeout.
  CONNECT_TIMEOUT,

  /// It occurs when url is sent timeout.
  SEND_TIMEOUT,

  ///It occurs when receiving timeout.
  RECEIVE_TIMEOUT,

  /// When the server response, but with a incorrect status, such as 404, 503...
  RESPONSE,

  /// When the request is cancelled, dio will throw a error with this type.
  CANCEL,

  /// Default error type, Some other Error. In this case, you can
  /// use the DioError.error if it is not null.
  UNKNOWN,
}

class StorageError extends QiniuError {
  final int code;
  final StorageErrorType type;

  StorageError({this.type, this.code, String message}) : super(message);

  @override
  String toString() {
    var msg = 'StorageRequestException [$type, $code]: $message';
    msg += '\n${StackTrace.current}';
    return msg;
  }
}

StorageErrorType mapDioErrorType(DioErrorType type) {
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
