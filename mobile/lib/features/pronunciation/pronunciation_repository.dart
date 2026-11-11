import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/learning_models.dart';

final pronunciationRepositoryProvider = Provider<PronunciationRepository>(
  (ref) => PronunciationRepository(ref.watch(apiClientProvider)),
);

class PronunciationRepository {
  const PronunciationRepository(this._api);

  final ApiClient _api;

  Future<List<MinimalPairSet>> loadPairs({String? category, String? level}) {
    final query = <String, String>{};
    if (category != null && category != 'all') query['category'] = category;
    if (level != null && level != 'all') query['level'] = level;

    final path = query.isEmpty
        ? '/v1/pronunciation/pairs'
        : '/v1/pronunciation/pairs?${Uri(queryParameters: query).query}';

    return _api.get<List<MinimalPairSet>>(
      path,
      (json) => (json as List<dynamic>? ?? const <dynamic>[])
          .map(MinimalPairSet.fromJson)
          .toList(growable: false),
    );
  }

  Future<MinimalPairSet> loadPair(String id) => _api.get<MinimalPairSet>(
    '/v1/pronunciation/pairs/$id',
    MinimalPairSet.fromJson,
  );

  Future<PhonemeAnalysisResult> analyzeAttempt({
    required String pairId,
    required String targetChoice,
    required String transcript,
    double durationSeconds = 3.0,
  }) => _api.post<PhonemeAnalysisResult>(
    '/v1/pronunciation/pairs/$pairId/analyze',
    <String, Object?>{
      'targetChoice': targetChoice,
      'transcript': transcript,
      'durationSeconds': durationSeconds,
    },
    PhonemeAnalysisResult.fromJson,
  );
}
