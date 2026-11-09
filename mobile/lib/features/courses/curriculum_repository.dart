import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/session_store.dart';
import '../../shared/models/learning_models.dart';
import '../home/roadmap_repository.dart';

final curriculumRepositoryProvider = Provider<CurriculumRepository>(
  (ref) => CurriculumRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStoreProvider),
    ref.watch(roadmapRepositoryProvider),
  ),
);

class CurriculumRepository {
  const CurriculumRepository(this._api, this._sessions, this._roadmaps);

  static const _lessonPrefix = 'toungular.lesson.v1.';
  static const _queuePrefix = 'toungular.lesson-actions.v1.';
  final ApiClient _api;
  final SessionStore _sessions;
  final RoadmapRepository _roadmaps;

  Future<LessonContent> loadLesson(String lessonId) async {
    final user = await _sessions.readSession();
    final key = _lessonPrefix + (user?.userId ?? 'guest') + '.' + lessonId;
    try {
      final lesson = await _api.get<LessonContent>(
        '/v1/lessons/$lessonId',
        LessonContent.fromJson,
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(key, jsonEncode(lesson.toJson()));
      return lesson;
    } on ApiException catch (error) {
      if (error.isUnauthorized) rethrow;
      final preferences = await SharedPreferences.getInstance();
      final cached = preferences.getString(key);
      if (cached != null) {
        try {
          return LessonContent.fromJson(jsonDecode(cached));
        } on FormatException {
          await preferences.remove(key);
        } on TypeError {
          await preferences.remove(key);
        }
      }

      final roadmap = await _roadmaps.load();
      for (final course in roadmap.courses) {
        for (final lesson in course.lessons) {
          if (lesson.id == lessonId) {
            return LessonContent(
              id: lesson.id,
              courseTitle: course.title,
              title: lesson.title,
              summary: lesson.summary,
              content: lesson.summary,
              durationMin: lesson.durationMin,
              completedAt: lesson.completedAt,
            );
          }
        }
      }
      rethrow;
    }
  }

  Future<DateTime> completeLesson(String lessonId) async {
    try {
      await _flushPending();
      final result = await _api.post<DateTime>(
        '/v1/lessons/$lessonId/complete',
        const <String, Object?>{},
        (json) {
          final map = json is Map ? json : const <Object?, Object?>{};
          return DateTime.tryParse(map['completedAt'] as String? ?? '') ?? DateTime.now();
        },
      );
      await _roadmaps.markLessonCompleteLocally(lessonId, result);
      return result;
    } on ApiException catch (error) {
      if (error.failure != ApiFailure.network && error.failure != ApiFailure.server) rethrow;
      await _enqueue(<String, Object?>{'kind': 'complete', 'lessonId': lessonId});
      final completedAt = DateTime.now();
      await _roadmaps.markLessonCompleteLocally(lessonId, completedAt);
      return completedAt;
    }
  }

  Future<void> _flushPending() async {
    final preferences = await SharedPreferences.getInstance();
    final queueKey = await _actionQueueKey();
    final encoded = preferences.getString(queueKey);
    if (encoded == null) return;
    List<dynamic> entries;
    try {
      entries = jsonDecode(encoded) as List<dynamic>;
    } on FormatException {
      await preferences.remove(_queueKey);
      return;
    } on TypeError {
      await preferences.remove(_queueKey);
      return;
    }
    final pending = <Map<String, Object?>>[];
    for (final raw in entries) {
      if (raw is! Map) continue;
      final action = raw.cast<String, Object?>();
      try {
        await _api.post<Object?>(
          '/v1/lessons/${action['lessonId']}/complete',
          const <String, Object?>{},
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
}
