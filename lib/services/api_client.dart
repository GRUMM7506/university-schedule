import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  ApiClient()
    : dio = Dio(
        BaseOptions(
          baseUrl: const String.fromEnvironment(
            'API_URL',
            defaultValue: 'http://127.0.0.1:8000/api',
          ),
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: false),
      );
    }
  }

  final Dio dio;
  String? token;
}
