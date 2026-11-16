import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/session_manager.dart';
import '../../shared/models/learning_models.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionManagerProvider),
  ),
);

class AuthRepository {
  const AuthRepository(this._api, this._sessions);

  final ApiClient _api;
  final SessionManager _sessions;

  Future<LearnerSession> register({
    required String email,
    required String password,
  }) => _authenticate('/v1/auth/register', <String, Object?>{
    'email': email.trim(),
    'password': password,
  });

  Future<LearnerSession> login({
    required String email,
    required String password,
  }) => _authenticate('/v1/auth/login', <String, Object?>{
    'email': email.trim(),
    'password': password,
  });

  /// Starts an account-less session that lives only on this device until the
  /// learner upgrades it with an email and password.
  Future<LearnerSession> continueAsGuest() =>
      _authenticate('/v1/auth/guest', const <String, Object?>{});

  /// Turns the current guest session into a permanent account in place, so the
  /// progress made without an account is kept.
  Future<LearnerSession> upgradeGuest({
    required String email,
    required String password,
  }) => _authenticate('/v1/auth/upgrade', <String, Object?>{
    'email': email.trim(),
    'password': password,
  });

  /// Revokes the refresh token server-side, then drops the local session.
  /// Local sign-out must succeed even when the API is unreachable.
  Future<void> logout() async {
    final refreshToken = await _sessions.refreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _api.post<Object?>('/v1/auth/logout', <String, Object?>{
          'refreshToken': refreshToken,
        }, (json) => json);
      } on ApiException {
        // The token expires on its own; still clear the device.
      }
    }
    await _sessions.clear();
  }

  Future<LearnerSession> _authenticate(
    String path,
    Map<String, Object?> body,
  ) async {
    final session = await _api.post<LearnerSession>(
      path,
      body,
      LearnerSession.fromAuthData,
    );
    _sessions.accept(session);
    return session;
  }
}
