import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/learning_models.dart';

final placementRepositoryProvider = Provider<PlacementRepository>(
  (ref) => PlacementRepository(ref.watch(apiClientProvider)),
);

class PlacementRepository {
  const PlacementRepository(this._api);
  final ApiClient _api;

  Future<List<PlacementQuestion>> loadVocabularyQuestions() =>
      _api.get<List<PlacementQuestion>>(
        '/v1/placement/questions',
        (json) => (json as List<dynamic>? ?? const <dynamic>[])
            .map(PlacementQuestion.fromJson)
            .toList(growable: false),
      );

  Future<PlacementResult> submitVocabularyAnswers(
    Map<String, String> answers,
  ) => _api.post<PlacementResult>('/v1/placement/vocabulary', <String, Object?>{
    'answers': answers.entries
        .map(
          (entry) => <String, String>{'itemId': entry.key, 'word': entry.value},
        )
        .toList(growable: false),
  }, PlacementResult.fromJson);
}
