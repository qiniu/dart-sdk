class QiniuError extends Error {
  final Error rawError;

  final String _message;

  String get message => _message ?? rawError?.toString() ?? '';

  @override
  StackTrace get stackTrace => rawError?.stackTrace ?? super.stackTrace;

  QiniuError({this.rawError, String message}) : _message = message;
}
