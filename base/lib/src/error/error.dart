class QiniuError extends Error {
  // 有的错误是不一定继承自 Error，比如 DioError 是实现的 Exception
  final Error rawError;

  final String _message;

  String get message => _message ?? rawError?.toString() ?? '';

  @override
  StackTrace get stackTrace => rawError?.stackTrace ?? super.stackTrace;

  QiniuError(this.rawError, this._message);
}
