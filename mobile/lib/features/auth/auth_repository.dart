import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/session_store.dart';
import '../../shared/models/learning_models.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStoreProvider),
  ),
);

class AuthRepository {
  const AuthRepository(this._api, this._sessionStore);

  final ApiClient _api;
  final SessionStore _sessionStore;

  Future<LearnerSession> register({
    required String email,
    required String password,
  }) =>
      _authenticate(
        '/v1/auth/register',
        <String, Object?>{'email': email.trim(), 'password': password},
      );

  Future<LearnerSession> login({
    required String email,
    required String password,
  }) =>
      _authenticate(
        '/v1/auth/login',
        <String, Object?>{'email': email.trim(), 'password': password},
      );

  Future<LearnerSession> refresh(String refreshToken) async {
    final session = await _api.post<LearnerSession>(
      '/v1/auth/refresh',
      <String, Object?>{'refreshToken': refreshToken},
      LearnerSession.fromAuthData,
    );
    await _sessionStore.writeSession(session);
    return session;
  }

  Future<void> logout() => _sessionStore.clearSession();

  Future<LearnerSession> _authenticate(
    String path,
    Map<String, Object?> body,
  ) async {
    final session = await _api.post<LearnerSession>(
      path,
      body,
      LearnerSession.fromAuthData,
    );
    await _sessionStore.writeSession(session);
    return session;
  }
}
