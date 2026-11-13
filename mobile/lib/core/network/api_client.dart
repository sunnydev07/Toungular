import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_environment.dart';
import 'session_manager.dart';

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(sessionManagerProvider)),
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
  ApiClient(this._sessions, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppEnvironment.apiBaseUrl,
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 20),
              headers: const <String, Object>{'Accept': 'application/json'},
            ),
          );

  final SessionManager _sessions;
  final Dio _dio;

  Future<T> get<T>(
    String path,
    T Function(Object? json) decoder, {
    CancelToken? cancelToken,
  }) => _request(path, 'GET', decoder, cancelToken: cancelToken);

  Future<T> post<T>(
    String path,
    Object? body,
    T Function(Object? json) decoder, {
    CancelToken? cancelToken,
  }) => _request(path, 'POST', decoder, body: body, cancelToken: cancelToken);

  Future<T> postRaw<T>(
    String path,
    List<int> bytes,
    String contentType,
    T Function(Object? json) decoder, {
    CancelToken? cancelToken,
  }) => _request(
    path,
    'POST',
    decoder,
    body: bytes,
    contentType: contentType,
    cancelToken: cancelToken,
  );

  Future<Uint8List> postBytes(
    String path,
    Object? body, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _send(
        path,
        'POST',
        body: body,
        responseType: ResponseType.bytes,
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data is Uint8List) return data;
      if (data is List<int>) return Uint8List.fromList(data);
      throw const ApiException(
        message: 'The voice response was not audio.',
        failure: ApiFailure.unknown,
      );
    } on DioException catch (error) {
      throw _translate(error);
    }
  }

  Future<T> patch<T>(
    String path,
    Object? body,
    T Function(Object? json) decoder, {
    CancelToken? cancelToken,
  }) => _request(path, 'PATCH', decoder, body: body, cancelToken: cancelToken);

  Future<T> put<T>(
    String path,
    Object? body,
    T Function(Object? json) decoder, {
    CancelToken? cancelToken,
  }) => _request(path, 'PUT', decoder, body: body, cancelToken: cancelToken);

  Future<T> delete<T>(
    String path,
    T Function(Object? json) decoder, {
    CancelToken? cancelToken,
  }) => _request(path, 'DELETE', decoder, cancelToken: cancelToken);

  Future<T> _request<T>(
    String path,
    String method,
    T Function(Object? json) decoder, {
    Object? body,
    String? contentType,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _send(
        path,
        method,
        body: body,
        contentType: contentType,
        cancelToken: cancelToken,
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

  /// Sends a request, and on a 401 rotates the access token once and retries.
  Future<Response<dynamic>> _send(
    String path,
    String method, {
    Object? body,
    String? contentType,
    ResponseType? responseType,
    CancelToken? cancelToken,
  }) async {
    // One key per logical POST: the 401 replay below reuses it so a retried
    // write is replayed server-side instead of double-charging quota.
    final String? idempotencyKey = method == 'POST'
        ? 'tng-${DateTime.now().microsecondsSinceEpoch}-${path.hashCode.abs()}'
        : null;

    Future<Response<dynamic>> attempt() async => _dio.request<dynamic>(
      path,
      data: body,
      options: Options(
        method: method,
        headers: <String, Object>{
          ...await _headers(),
          'Idempotency-Key': ?idempotencyKey,
        },
        contentType: contentType,
        responseType: responseType,
      ),
      cancelToken: cancelToken,
    );

    try {
      return await attempt();
    } on DioException catch (error) {
      // Access tokens live 15 minutes, so a 401 is routine rather than a
      // signed-out session. Rotate the token and replay the request once.
      if (error.response?.statusCode != 401) rethrow;
      // Login and refresh failures are the server's answer, but logout should
      // retry with a rotated access token so the refresh token is revoked.
      if (path.startsWith('/v1/auth/') && path != '/v1/auth/logout') rethrow;
      if (await _sessions.refresh() == null) rethrow;
      return attempt();
    }
  }

  Future<Map<String, Object>> _headers() async {
    final token = await _sessions.accessToken();
    final headers = <String, Object>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  ApiException _translate(DioException error) {
    final status = error.response?.statusCode;
    final body = error.response?.data;
    var message =
        'Could not reach Toungular. Check your connection and try again.';
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
