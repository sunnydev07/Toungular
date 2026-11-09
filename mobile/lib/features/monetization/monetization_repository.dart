import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/learning_models.dart';

final monetizationRepositoryProvider = Provider<MonetizationRepository>((ref) => MonetizationRepository(ref.watch(apiClientProvider)));
final entitlementSnapshotProvider = FutureProvider<EntitlementSnapshot>(
  (ref) => ref.watch(monetizationRepositoryProvider).entitlements(),
);

class MonetizationRepository {
  const MonetizationRepository(this._api);
  final ApiClient _api;

  Future<EntitlementSnapshot> entitlements() => _api.get<EntitlementSnapshot>('/v1/entitlements', EntitlementSnapshot.fromJson);
  Future<ReferralSummary> referral() => _api.get<ReferralSummary>('/v1/referrals/me', ReferralSummary.fromJson);

  Future<void> redeem(String code) async {
    await _api.post<Object?>('/v1/referrals/redeem', <String, Object?>{'code': code}, (json) => json);
  }

  Future<void> restore() async {
    await _api.post<Object?>(
      '/v1/billing/restore',
      const <String, Object?>{'receipts': <Object?>[]},
      (json) => json,
    );
  }
}
