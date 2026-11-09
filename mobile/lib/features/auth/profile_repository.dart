import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/session_store.dart';
import '../../shared/models/learning_models.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStoreProvider),
  ),
);

class ProfileRepository {
  const ProfileRepository(this._api, this._sessionStore);

  final ApiClient _api;
  final SessionStore _sessionStore;

  Future<LearnerProfile> update({
    required List<String> goals,
    required Proficiency proficiency,
    required int dailyMinutes,
    required String timezone,
    required bool ieltsIntent,
  }) async {
    final profile = await _api.patch<LearnerProfile>(
      '/v1/me',
      <String, Object?>{
        'goals': goals,
        'proficiency': proficiency.name,
        'dailyMinutes': dailyMinutes,
        'timezone': timezone,
        'ieltsIntent': ieltsIntent,
      },
      LearnerProfile.fromJson,
    );
    await _sessionStore.updateProfile(profile);
    return profile;
  }

  Future<void> deleteAccount() async {
    await _api.delete<Object?>('/v1/me', (json) => json);
    await _sessionStore.clearSession();
  }
}
