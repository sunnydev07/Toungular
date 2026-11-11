import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../shared/models/learning_models.dart';

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'toungular.session.v1';
  final FlutterSecureStorage _storage;

  Future<LearnerSession?> readSession() async {
    final encoded = await _storage.read(key: _sessionKey);
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return LearnerSession.fromJson(jsonDecode(encoded));
    } on FormatException {
      await clearSession();
      return null;
    } on TypeError {
      await clearSession();
      return null;
    }
  }

  Future<void> writeSession(LearnerSession session) =>
      _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));

  Future<String?> readAccessToken() async => (await readSession())?.accessToken;

  Future<void> updateProfile(LearnerProfile profile) async {
    final session = await readSession();
    if (session == null) return;
    await writeSession(session.withProfile(profile));
  }

  Future<void> clearSession() => _storage.delete(key: _sessionKey);
}
