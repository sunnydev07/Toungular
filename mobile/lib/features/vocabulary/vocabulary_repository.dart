import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/session_store.dart';
import '../../shared/models/learning_models.dart';

final vocabularyRepositoryProvider = Provider<VocabularyRepository>(
  (ref) => VocabularyRepository(ref.watch(apiClientProvider), ref.watch(sessionStoreProvider)),
);

class VocabularyRepository {
  const VocabularyRepository(this._api, this._sessions);

  static const _cachePrefix = 'toungular.vocab-due.v2.';
  static const _queuePrefix = 'toungular.vocab-actions.v1.';
  final ApiClient _api;
  final SessionStore _sessions;

  Future<List<VocabularyReview>> loadDueItems() async {
    final user = await _sessions.readSession();
    final key = _cachePrefix + (user?.userId ?? 'guest');
    try {
      await _flushPending();
      final items = await _api.get<List<VocabularyReview>>(
        '/v1/vocabulary/due',
        (json) => (json as List<dynamic>? ?? const <dynamic>[])
            .map(VocabularyReview.fromJson)
            .toList(growable: false),
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(key, jsonEncode(items.map((item) => item.toJson()).toList()));
      return items;
    } on ApiException catch (error) {
      if (error.isUnauthorized) rethrow;
      final preferences = await SharedPreferences.getInstance();
      final encoded = preferences.getString(key);
      if (encoded == null) rethrow;
      try {
        return (jsonDecode(encoded) as List<dynamic>)
            .map(VocabularyReview.fromJson)
            .toList(growable: false);
      } on FormatException {
        await preferences.remove(key);
        rethrow;
      } on TypeError {
        await preferences.remove(key);
        rethrow;
      }
    }
  }

  Future<void> submitReview(String itemId, String grade, {String? mode}) async {
    if (!const <String>{'again', 'hard', 'good', 'easy'}.contains(grade)) {
      throw ArgumentError.value(grade, 'grade', 'Unknown vocabulary review grade.');
    }
    final payload = <String, Object?>{'grade': grade, if (mode != null) 'mode': mode};
    try {
      await _flushPending();
      await _api.post<Object?>(
        '/v1/vocabulary/$itemId/review',
        payload,
        (json) => json,
      );
    } on ApiException catch (error) {
      if (error.failure != ApiFailure.network && error.failure != ApiFailure.server) rethrow;
      await _enqueue(<String, Object?>{'itemId': itemId, ...payload});
    }
    await _removeFromCachedDue(itemId);
  }

  Future<VocabularyReview> addWord({
    required String word,
    required String partOfSpeech,
    required String definition,
    required String example,
    required String level,
    int? tier,
  }) =>
      _api.post<VocabularyReview>(
        '/v1/vocabulary',
        <String, Object?>{
          'word': word,
          'partOfSpeech': partOfSpeech,
          'definition': definition,
          'example': example,
          'level': level,
          if (tier != null) 'tier': tier,
        },
        VocabularyReview.fromJson,
      );

  Future<void> _flushPending() async {
    final preferences = await SharedPreferences.getInstance();
    final queueKey = await _actionQueueKey();
    final encoded = preferences.getString(queueKey);
    if (encoded == null) return;
    List<dynamic> entries;
    try {
      entries = jsonDecode(encoded) as List<dynamic>;
    } on FormatException {
      await preferences.remove(queueKey);
      return;
    } on TypeError {
      await preferences.remove(queueKey);
      return;
    }
    final pending = <Map<String, Object?>>[];
    for (final raw in entries) {
      if (raw is! Map) continue;
      final action = raw.cast<String, Object?>();
      try {
        await _api.post<Object?>(
          '/v1/vocabulary/${action['itemId']}/review',
          <String, Object?>{
            'grade': action['grade'],
            if (action['mode'] != null) 'mode': action['mode'],
          },
          (json) => json,
        );
      } on ApiException catch (error) {
        if (error.failure == ApiFailure.unauthorized) rethrow;
        pending.add(action);
      }
    }
    if (pending.isEmpty) {
      await preferences.remove(queueKey);
    } else {
      await preferences.setString(queueKey, jsonEncode(pending));
    }
  }

  Future<void> _enqueue(Map<String, Object?> action) async {
    final preferences = await SharedPreferences.getInstance();
    final queueKey = await _actionQueueKey();
    final encoded = preferences.getString(queueKey);
    final actions = encoded == null ? <dynamic>[] : jsonDecode(encoded) as List<dynamic>;
    actions.add(action);
    await preferences.setString(queueKey, jsonEncode(actions));
  }

  Future<String> _actionQueueKey() async {
    final session = await _sessions.readSession();
    return _queuePrefix + (session?.userId ?? 'guest');
  }

  Future<void> _removeFromCachedDue(String itemId) async {
    final user = await _sessions.readSession();
    final preferences = await SharedPreferences.getInstance();
    final key = _cachePrefix + (user?.userId ?? 'guest');
    final encoded = preferences.getString(key);
    if (encoded == null) return;
    try {
      final items = (jsonDecode(encoded) as List<dynamic>)
          .map(VocabularyReview.fromJson)
          .where((review) => review.item.id != itemId)
          .map((review) => review.toJson())
          .toList();
      await preferences.setString(key, jsonEncode(items));
    } on FormatException {
      await preferences.remove(key);
    } on TypeError {
      await preferences.remove(key);
    }
  }
}
