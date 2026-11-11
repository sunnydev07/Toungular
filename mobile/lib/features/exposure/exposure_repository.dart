import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/learning_models.dart';

final exposureRepositoryProvider = Provider<ExposureRepository>(
  (ref) => ExposureRepository(ref.watch(apiClientProvider)),
);

class ExposureRepository {
  const ExposureRepository(this._api);

  final ApiClient _api;

  Future<ExposureSummary> load() => _api.get<ExposureSummary>('/v1/exposure', ExposureSummary.fromJson);

  Future<ExposureSummary> complete(int level) => _api.post<ExposureSummary>(
        '/v1/exposure/$level/complete',
        const <String, Object?>{},
        ExposureSummary.fromJson,
      );
}
