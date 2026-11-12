import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/learning_models.dart';
import '../auth/session_controller.dart';

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(ref.watch(apiClientProvider)),
);

/// Shared progress summary so the Today and Progress tabs agree, and so the
/// request is cancelled when no screen is watching it any more.
final progressSummaryProvider = FutureProvider.autoDispose<ProgressSummary>((
  ref,
) {
  ref.watch(sessionControllerProvider.select((state) => state.session?.userId));
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  return ref
      .watch(progressRepositoryProvider)
      .loadSummary(cancelToken: cancelToken);
});

/// Shared streak snapshot; the Today card and Progress reminders read the
/// same response instead of issuing competing requests.
final streakProvider = FutureProvider.autoDispose<HabitSnapshot>((ref) {
  ref.watch(sessionControllerProvider.select((state) => state.session?.userId));
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  return ref
      .watch(progressRepositoryProvider)
      .loadStreak(cancelToken: cancelToken);
});

class ProgressRepository {
  const ProgressRepository(this._api);
  final ApiClient _api;

  Future<ProgressSummary> loadSummary({CancelToken? cancelToken}) =>
      _api.get<ProgressSummary>(
        '/v1/progress',
        ProgressSummary.fromJson,
        cancelToken: cancelToken,
      );
  Future<HabitSnapshot> loadStreak({CancelToken? cancelToken}) =>
      _api.get<HabitSnapshot>(
        '/v1/streak',
        HabitSnapshot.fromJson,
        cancelToken: cancelToken,
      );

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
