import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/learning_models.dart';

final shadowRepositoryProvider = Provider<ShadowRepository>(
  (ref) => ShadowRepository(ref.watch(apiClientProvider)),
);

class ShadowRepository {
  const ShadowRepository(this._api);

  final ApiClient _api;

  Future<List<ShadowPassage>> loadPassages() => _api.get<List<ShadowPassage>>(
    '/v1/shadow/passages',
    (json) => (json as List<dynamic>? ?? const <dynamic>[])
        .map(ShadowPassage.fromJson)
        .toList(growable: false),
  );

  Future<ShadowPassage> loadPassage(String id) => _api.get<ShadowPassage>(
    '/v1/shadow/passages/$id',
    ShadowPassage.fromJson,
  );

  Future<ShadowAnalysisResult> analyze({
    required String passageId,
    required int durationSeconds,
    required String transcript,
    List<double>? pauses,
  }) => _api.post<ShadowAnalysisResult>('/v1/shadow/analyze', <String, Object?>{
    'passageId': passageId,
    'durationSeconds': durationSeconds,
    'transcript': transcript,
    if (pauses != null) 'pauses': pauses,
  }, ShadowAnalysisResult.fromJson);
}
