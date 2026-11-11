import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/learning_models.dart';

final masteryRepositoryProvider = Provider<MasteryRepository>(
  (ref) => MasteryRepository(ref.watch(apiClientProvider)),
);

class MasteryRepository {
  const MasteryRepository(this._api);

  final ApiClient _api;

  Future<MasteryProfile> getProfile() => _api.get<MasteryProfile>(
        '/v1/mastery/profile',
        MasteryProfile.fromJson,
      );

  Future<AwardXpResult> awardXp({
    required String category,
    required int points,
    required String reason,
  }) =>
      _api.post<AwardXpResult>(
        '/v1/mastery/award',
        <String, Object?>{
          'category': category,
          'points': points,
          'reason': reason,
        },
        AwardXpResult.fromJson,
      );

  Future<MasteryProfile> useFreezeToken() => _api.post<MasteryProfile>(
        '/v1/mastery/freeze-token',
        const <String, Object?>{},
        MasteryProfile.fromJson,
      );
}
