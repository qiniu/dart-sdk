import 'package:dio/dio.dart';

/// Web 平台不支持 dart:io，使用 dio 默认 adapter
HttpClientAdapter createDefaultDelegate(int? sendBufferSize) {
  return HttpClientAdapter();
}
