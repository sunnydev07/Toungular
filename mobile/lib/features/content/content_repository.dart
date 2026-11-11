import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/learning_models.dart';

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => ContentRepository(ref.watch(apiClientProvider)),
);

class ContentRepository {
  const ContentRepository(this._api);

  final ApiClient _api;

  Future<List<ContentArticle>> loadArticles({String? level}) {
    final query = level != null && level.isNotEmpty && level != 'All' ? '?level=$level' : '';
    return _api.get<List<ContentArticle>>(
      '/v1/content/articles$query',
      (json) => (json as List<dynamic>? ?? const <dynamic>[])
          .map(ContentArticle.fromJson)
          .toList(growable: false),
    );
  }

  Future<ContentArticle> loadArticle(String id) => _api.get<ContentArticle>(
        '/v1/content/articles/$id',
        ContentArticle.fromJson,
      );

  Future<ArticleEvaluationResult> evaluateOutput({
    required String articleId,
    required String text,
  }) =>
      _api.post<ArticleEvaluationResult>(
        '/v1/content/articles/$articleId/evaluate',
        <String, Object?>{
          'text': text,
        },
        ArticleEvaluationResult.fromJson,
      );
}
