import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/learning_models.dart';
import '../config/app_environment.dart';
import '../storage/session_store.dart';

final sessionManagerProvider = Provider<SessionManager>((ref) {
  final manager = SessionManager(ref.watch(sessionStoreProvider));
  ref.onDispose(manager.dispose);
  return manager;
});

/// Owns the learner session: the in-memory copy, secure-storage writes, the
/// single-flight refresh rotation, and the "session was rejected" signal.
///
/// The backend burns a refresh token on first use, so exactly one rotation may
/// be in flight. Everything that needs a token (the API client, startup
/// restore, sign-out) goes through this class instead of reading the store.
class SessionManager {
  SessionManager(this._store, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppEnvironment.apiBaseUrl,
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
            ),
          );

  final SessionStore _store;
  final Dio _dio;
  final StreamController<void> _expired = StreamController<void>.broadcast();

  LearnerSession? _cached;
  Future<LearnerSession?>? _refreshing;

  /// Emits when the server rejects the refresh token, i.e. the learner must
  /// sign in again. Network failures never emit.
  Stream<void> get expired => _expired.stream;

  /// Restores the saved session at startup, rotating the access token when
  /// possible. A rejected token clears the session; an offline start keeps it.
  Future<LearnerSession?> restore() async {
    final saved = await _store.readSession();
    _cached = saved;
    if (saved == null) return null;
    final refreshed = await refresh();
    return refreshed ?? _cached;
  }

  Future<String?> accessToken() async {
    final cached = _cached;
    if (cached != null) return cached.accessToken;
    final saved = await _store.readSession();
    _cached = saved;
    return saved?.accessToken;
  }

  Future<String?> refreshToken() async =>
      (_cached ?? await _store.readSession())?.refreshToken;

  /// Rotates the refresh token once; concurrent callers share the same future.
  Future<LearnerSession?> refresh() {
    final pending = _refreshing;
    if (pending != null) return pending;
    final rotating = _rotate();
    _refreshing = rotating;
    return rotating.whenComplete(() => _refreshing = null);
  }

  Future<LearnerSession?> _rotate() async {
    final token = (await _store.readSession())?.refreshToken ?? '';
    if (token.isEmpty) return null;
    try {
      final response = await _dio.post<dynamic>(
        '/v1/auth/refresh',
        data: <String, Object?>{'refreshToken': token},
      );
      final body = response.data;
      final payload = body is Map && body.containsKey('data')
          ? body['data']
          : body;
      final refreshed = LearnerSession.fromAuthData(payload);
      if (refreshed.accessToken.isEmpty || refreshed.refreshToken.isEmpty) {
        await _expire();
        return null;
      }
      _cached = refreshed;
      await _store.writeSession(refreshed);
      return refreshed;
    } on DioException catch (error) {
      // Only a rejected refresh token ends the session; offline keeps it.
      if (error.response?.statusCode == 401) await _expire();
      return null;
    } catch (_) {
      return null;
    }
  }

  void accept(LearnerSession session) {
    _cached = session;
    unawaited(_store.writeSession(session));
  }

  Future<void> updateProfile(LearnerProfile profile) async {
    final current = _cached ?? await _store.readSession();
    if (current == null) return;
    final next = current.withProfile(profile);
    _cached = next;
    await _store.writeSession(next);
  }

  Future<void> clear() async {
    _cached = null;
    await _store.clearSession();
  }

  Future<void> _expire() async {
    final hadSession = _cached != null || await _store.readSession() != null;
    _cached = null;
    await _store.clearSession();
    if (hadSession && !_expired.isClosed) _expired.add(null);
  }

  void dispose() {
    unawaited(_expired.close());
  }
}
