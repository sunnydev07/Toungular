import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/learning_models.dart';

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(ref.watch(apiClientProvider)),
);

class ProgressRepository {
  const ProgressRepository(this._api);
  final ApiClient _api;

  Future<ProgressSummary> loadSummary() =>
      _api.get<ProgressSummary>('/v1/progress', ProgressSummary.fromJson);
  Future<HabitSnapshot> loadStreak() =>
      _api.get<HabitSnapshot>('/v1/streak', HabitSnapshot.fromJson);

  Future<void> updateReminder({
    required String? time,
    required List<int> days,
  }) async {
    await _api.put<Object?>('/v1/reminders', <String, Object?>{
      'time': time,
      'days': days,
    }, (json) => json);
  }
}
