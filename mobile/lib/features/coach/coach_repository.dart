import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/learning_models.dart';

final coachRepositoryProvider = Provider<CoachRepository>((ref) => CoachRepository(ref.watch(apiClientProvider)));

class CoachRepository {
  const CoachRepository(this._api);
  final ApiClient _api;

  Future<List<CoachScenario>> scenarios() => _api.get<List<CoachScenario>>(
        '/v1/coach/scenarios',
        (json) => (json as List<dynamic>? ?? const <dynamic>[]).map(CoachScenario.fromJson).toList(growable: false),
      );

  Future<CoachConversation> start(String scenarioId) => _api.post<CoachConversation>(
        '/v1/conversations',
        <String, Object?>{'scenarioId': scenarioId},
        CoachConversation.fromJson,
      );

  Future<CoachConversation> load(String id) => _api.get<CoachConversation>(
        '/v1/conversations/$id',
        CoachConversation.fromJson,
      );

  Future<CoachTurnReceipt> sendTurn(String id, String transcript) => _api.post<CoachTurnReceipt>(
        '/v1/conversations/$id/turns',
        <String, Object?>{'transcript': transcript},
        CoachTurnReceipt.fromJson,
      );

  Future<String> finish(String id) => _api.post<String>(
        '/v1/conversations/$id/finish',
        const <String, Object?>{},
        (json) => json is Map ? json['summary'] as String? ?? 'Practice saved.' : 'Practice saved.',
      );

  Future<void> delete(String id) async {
    await _api.delete<Object?>('/v1/conversations/$id', (json) => json);
  }
}
