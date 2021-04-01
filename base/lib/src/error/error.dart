class QiniuError extends Error {
  /// error or exception
  final dynamic rawError;

  final String? _message;

  String get message => _message ?? rawError?.toString() ?? '';

  @override
  StackTrace? get stackTrace {
    if (rawError is Error) {
      return (rawError as Error).stackTrace;
    }

    return super.stackTrace;
  }

  QiniuError({this.rawError, String? message}) : _message = message;
}
