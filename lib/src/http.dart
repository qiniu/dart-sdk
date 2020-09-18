import 'package:dio/dio.dart';

class Http {
  final Dio _client = Dio();

  Future<Response<T>> post<T>() {
    _client.post;
  }
}
