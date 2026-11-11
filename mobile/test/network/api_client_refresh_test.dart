import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toungular/core/network/api_client.dart';
import 'package:toungular/core/storage/session_store.dart';
import 'package:toungular/shared/models/learning_models.dart';

class _MemorySessionStore extends SessionStore {
  _MemorySessionStore(this.session);

  LearnerSession? session;
  int clears = 0;

  @override
  Future<LearnerSession?> readSession() async => session;

  @override
  Future<void> writeSession(LearnerSession value) async => session = value;

  @override
  Future<String?> readAccessToken() async => session?.accessToken;

  @override
  Future<void> clearSession() async {
    clears += 1;
    session = null;
  }
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<String> paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    paths.add(options.path);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object? body, int status) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>[Headers.jsonContentType],
  },
);

Map<String, Object?> _authBody(String accessToken, String refreshToken) =>
    <String, Object?>{
      'user': <String, Object?>{'id': 'user-1', 'email': 'learner@toungular.app'},
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    };

LearnerSession _session(String accessToken, String refreshToken) =>
    LearnerSession.fromJson(<String, Object?>{
      'userId': 'user-1',
      'email': 'learner@toungular.app',
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    });

ApiClient _client(_MemorySessionStore store, _FakeAdapter adapter) =>
    ApiClient(
      store,
      dio: Dio(BaseOptions(baseUrl: 'http://toungular.test'))
        ..httpClientAdapter = adapter,
    );

void main() {
  test('rotates an expired access token and replays the request', () async {
    final store = _MemorySessionStore(_session('access-1', 'refresh-1'));
    final adapter = _FakeAdapter((options) async {
      if (options.path == '/v1/auth/refresh') {
        expect((options.data as Map)['refreshToken'], 'refresh-1');
        return _json({
          'data': _authBody('access-2', 'refresh-2'),
        }, 200);
      }
      if (options.headers['Authorization'] == 'Bearer access-2') {
        return _json({
          'data': {'ok': true},
        }, 200);
      }
      return _json({
        'error': {'message': 'Token expired.'},
      }, 401);
    });

    final result = await _client(store, adapter).get<Map<String, Object?>>(
      '/v1/me',
      (json) => json! as Map<String, Object?>,
    );

    expect(result['ok'], isTrue);
    expect(store.session!.accessToken, 'access-2');
    expect(store.session!.refreshToken, 'refresh-2');
    expect(adapter.paths, <String>['/v1/me', '/v1/auth/refresh', '/v1/me']);
  });

  test('shares one rotation across concurrent 401 responses', () async {
    final store = _MemorySessionStore(_session('access-1', 'refresh-1'));
    var refreshes = 0;
    final adapter = _FakeAdapter((options) async {
      if (options.path == '/v1/auth/refresh') {
        refreshes += 1;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return _json({
          'data': _authBody('access-2', 'refresh-2'),
        }, 200);
      }
      if (options.headers['Authorization'] == 'Bearer access-2') {
        return _json({'data': {'ok': true}}, 200);
      }
      return _json({
        'error': {'message': 'Token expired.'},
      }, 401);
    });
    final client = _client(store, adapter);

    final results = await Future.wait(<Future<Object?>>[
      for (final path in <String>['/v1/me', '/v1/lessons', '/v1/streak'])
        client.get<Object?>(path, (json) => json),
    ]);

    expect(refreshes, 1);
    expect(results, hasLength(3));
    expect(store.session!.refreshToken, 'refresh-2');
  });

  test('clears a dead session when the refresh token is rejected', () async {
    final store = _MemorySessionStore(_session('access-1', 'refresh-1'));
    final adapter = _FakeAdapter(
      (options) async => _json({
        'error': {'message': 'Refresh token expired.'},
      }, 401),
    );

    await expectLater(
      _client(store, adapter).get<Object?>('/v1/me', (json) => json),
      throwsA(
        isA<ApiException>().having(
          (error) => error.isUnauthorized,
          'isUnauthorized',
          isTrue,
        ),
      ),
    );
    expect(store.clears, 1);
    expect(store.session, isNull);
  });
}
