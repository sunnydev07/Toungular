import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/learning_models.dart';

final ieltsRepositoryProvider = Provider<IeltsRepository>(
  (ref) => IeltsRepository(ref.watch(apiClientProvider)),
);

class IeltsResponseArgs {
  const IeltsResponseArgs({required this.attemptId, required this.section});
  final String attemptId;
  final IeltsSection section;
}

class IeltsRepository {
  const IeltsRepository(this._api);
  final ApiClient _api;

  Future<List<IeltsMock>> loadMocks() => _api.get<List<IeltsMock>>(
    '/v1/ielts/mocks',
    (json) => (json as List<dynamic>? ?? const <dynamic>[])
        .map(IeltsMock.fromJson)
        .toList(growable: false),
  );

  Future<IeltsAttemptReference> startAttempt(String mockId) =>
      _api.post<IeltsAttemptReference>('/v1/ielts/attempts', <String, Object?>{
        'mockId': mockId,
      }, IeltsAttemptReference.fromJson);

  Future<List<IeltsAttemptRecord>> history() =>
      _api.get<List<IeltsAttemptRecord>>(
        '/v1/ielts/attempts',
        (json) => (json as List<dynamic>? ?? const <dynamic>[])
            .map(IeltsAttemptRecord.fromJson)
            .toList(growable: false),
      );

  Future<void> submitResponse(
    String attemptId,
    String sectionId,
    String transcript,
  ) async {
    await _api.post<Object?>(
      '/v1/ielts/attempts/$attemptId/responses',
      <String, Object?>{'sectionId': sectionId, 'transcript': transcript},
      (json) => json,
    );
  }

  Future<IeltsAttemptRecord> finishAttempt(String attemptId) =>
      _api.post<IeltsAttemptRecord>(
        '/v1/ielts/attempts/$attemptId/finish',
        const <String, Object?>{},
        IeltsAttemptRecord.fromJson,
      );
}
