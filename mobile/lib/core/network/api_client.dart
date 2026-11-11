import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_environment.dart';
import '../storage/session_store.dart';

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(sessionStoreProvider)),
);

enum ApiFailure { network, unauthorized, validation, server, unknown }

class ApiException implements Exception {
  const ApiException({
    required this.message,
    required this.failure,
    this.statusCode,
  });

  final String message;
  final ApiFailure failure;
  final int? statusCode;

  bool get isUnauthorized => failure == ApiFailure.unauthorized;
  bool get isNetworkUnavailable => failure == ApiFailure.network;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this._sessionStore)
      : _dio = Dio(BaseOptions(
          baseUrl: AppEnvironment.apiBaseUrl,
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
          headers: const <String, Object>{'Accept': 'application/json'},
        ));

  final SessionStore _sessionStore;
  final Dio _dio;

  Future<T> get<T>(String path, T Function(Object? json) decoder) =>
      _request(path, 'GET', decoder);

  Future<T> post<T>(
    String path,
    Object? body,
    T Function(Object? json) decoder,
  ) =>
      _request(path, 'POST', decoder, body: body);

  Future<T> postRaw<T>(
    String path,
    List<int> bytes,
    String contentType,
    T Function(Object? json) decoder,
  ) =>
      _request(path, 'POST', decoder, body: bytes, contentType: contentType);

  Future<Uint8List> postBytes(String path, Object? body) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: body,
        options: Options(
          responseType: ResponseType.bytes,
          headers: await _headers(),
        ),
      );
      final data = response.data;
      if (data is Uint8List) return data;
      if (data is List<int>) return Uint8List.fromList(data);
      throw const ApiException(message: 'The voice response was not audio.', failure: ApiFailure.unknown);
    } on DioException catch (error) {
      throw _translate(error);
    }
  }

  Future<T> patch<T>(
    String path,
    Object? body,
    T Function(Object? json) decoder,
  ) =>
      _request(path, 'PATCH', decoder, body: body);

  Future<T> put<T>(
    String path,
    Object? body,
    T Function(Object? json) decoder,
  ) =>
      _request(path, 'PUT', decoder, body: body);

  Future<T> delete<T>(String path, T Function(Object? json) decoder) =>
      _request(path, 'DELETE', decoder);

  Future<T> _request<T>(
    String path,
    String method,
    T Function(Object? json) decoder, {
    Object? body,
    String? contentType,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        options: Options(
          method: method,
          headers: await _headers(),
          contentType: contentType,
        ),
      );
      final responseBody = response.data;
      if (responseBody is Map && responseBody.containsKey('data')) {
        return decoder(responseBody['data']);
      }
      return decoder(responseBody);
    } on DioException catch (error) {
      throw _translate(error);
    }
  }

  Future<Map<String, Object>> _headers() async {
    final token = await _sessionStore.readAccessToken();
    final headers = <String, Object>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  ApiException _translate(DioException error) {
    final status = error.response?.statusCode;
    final body = error.response?.data;
    var message = 'Could not reach Toungular. Check your connection and try again.';
    var failure = ApiFailure.network;

    if (status != null) {
      failure = switch (status) {
        401 => ApiFailure.unauthorized,
        400 || 422 => ApiFailure.validation,
        >= 500 => ApiFailure.server,
        _ => ApiFailure.unknown,
      };
      if (body is Map && body['error'] is Map) {
        final apiMessage = (body['error'] as Map)['message'];
        if (apiMessage is String && apiMessage.isNotEmpty) message = apiMessage;
      } else if (status >= 500) {
        message = 'Toungular is unavailable right now. Please try again soon.';
      }
    } else if (error.type == DioExceptionType.cancel) {
      message = 'This request was cancelled.';
      failure = ApiFailure.unknown;
    }
    return ApiException(message: message, failure: failure, statusCode: status);
  }
}
