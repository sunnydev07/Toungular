import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/session_store.dart';
import '../../shared/models/learning_models.dart';
import '../auth/session_controller.dart';

final speakingRepositoryProvider = Provider<SpeakingRepository>(
  (ref) => SpeakingRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStoreProvider),
  ),
);

/// Shared speaking history for Today, Practice, and the history screen.
///
/// The token is cancelled when the last listener goes away, which keeps a
/// disposed screen from holding an open request.
final speakingHistoryProvider =
    FutureProvider.autoDispose<List<SpeakingSessionSummary>>((ref) {
      ref.watch(
        sessionControllerProvider.select((state) => state.session?.userId),
      );
      final cancelToken = CancelToken();
      ref.onDispose(cancelToken.cancel);
      return ref
          .watch(speakingRepositoryProvider)
          .history(cancelToken: cancelToken);
    });

class SpeakingRepository {
  const SpeakingRepository(this._api, this._sessions);

  final ApiClient _api;
  final SessionStore _sessions;

  Future<SpeakingSessionSummary> create({
    required String prompt,
    String type = 'prompt',
  }) => _api.post<SpeakingSessionSummary>(
    '/v1/speaking-sessions',
    <String, Object?>{'type': type, 'prompt': prompt},
    SpeakingSessionSummary.fromJson,
  );

  Future<void> saveTranscript(String id, String transcript) async {
    await _api.put<Object?>(
      '/v1/speaking-sessions/$id/transcript',
      <String, Object?>{'transcript': transcript},
      (json) => json,
    );
  }

  Future<SpeakingFeedback> analyze(
    String id,
    int durationSeconds, {
    String? transcript,
    List<double> pauses = const <double>[],
  }) => _api.post<SpeakingFeedback>(
    '/v1/speaking-sessions/$id/analyze',
    <String, Object?>{
      'durationSeconds': durationSeconds.clamp(1, 600),
      'transcript': ?transcript,
      if (pauses.isNotEmpty) 'pauses': pauses,
    },
    SpeakingFeedback.fromJson,
  );

  Future<List<SpeakingSessionSummary>> history({CancelToken? cancelToken}) =>
      _api.get<List<SpeakingSessionSummary>>(
        '/v1/speaking-sessions',
        (json) => (json as List<dynamic>? ?? const <dynamic>[])
            .map(SpeakingSessionSummary.fromJson)
            .toList(growable: false),
        cancelToken: cancelToken,
      );

  Future<AffectiveAssessmentResult> assessAffectiveState({
    required String transcript,
    required int durationSeconds,
    required int pauseCount,
    required double wpm,
  }) => _api.post<AffectiveAssessmentResult>(
    '/v1/decision/affective-state',
    <String, Object?>{
      'transcript': transcript,
      'durationSeconds': durationSeconds,
      'pauseCount': pauseCount,
      'wpm': wpm,
    },
    AffectiveAssessmentResult.fromJson,
  );

  Future<void> saveAudioPath(String sessionId, String path) async {
    final session = await _sessions.readSession();
    if (session == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_audioKey(session.userId, sessionId), path);
  }

  Future<String?> audioPath(String sessionId) async {
    final session = await _sessions.readSession();
    if (session == null) return null;
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_audioKey(session.userId, sessionId));
  }

  String _audioKey(String userId, String sessionId) =>
      'toungular.speaking-audio.v1.$userId.$sessionId';
}
