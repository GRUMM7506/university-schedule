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
        onError: (DioException e, handler) {
          if (e.response?.statusCode == 401) {
            onSessionExpired?.call();
          } else {
            var detail = e.response?.data?['detail'];
            String message;
            if (detail is List) {
              message = detail.map((e) => e is Map ? e['msg'] : e.toString()).join('\n');
            } else {
              message = detail?.toString() ?? e.message ?? 'Произошла ошибка сети';
            }
            onError?.call(message);
          }
          handler.next(e);
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

  /// Callback for general API errors to be shown in UI
  void Function(String message)? onError;

  /// Callback for 401 Unauthorized errors
  void Function()? onSessionExpired;
}
