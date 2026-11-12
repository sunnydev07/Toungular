import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/learning_models.dart';

final masteryRepositoryProvider = Provider<MasteryRepository>(
  (ref) => MasteryRepository(ref.watch(apiClientProvider)),
);

class MasteryRepository {
  const MasteryRepository(this._api);

  final ApiClient _api;

  Future<MasteryProfile> getProfile() =>
      _api.get<MasteryProfile>('/v1/mastery/profile', MasteryProfile.fromJson);

  Future<MasteryProfile> useFreezeToken() => _api.post<MasteryProfile>(
    '/v1/mastery/freeze-token',
    const <String, Object?>{},
    MasteryProfile.fromJson,
  );
}
