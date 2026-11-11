import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/session_store.dart';
import '../../shared/models/learning_models.dart';

final roadmapRepositoryProvider = Provider<RoadmapRepository>(
  (ref) => RoadmapRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStoreProvider),
  ),
);

class RoadmapRepository {
  const RoadmapRepository(this._api, this._sessionStore);

  static const _cachePrefix = 'toungular.roadmap.v1.';
  final ApiClient _api;
  final SessionStore _sessionStore;

  Future<Roadmap> load() async {
    try {
      final roadmap = await _api.get<Roadmap>('/v1/roadmap', Roadmap.fromJson);
      final session = await _sessionStore.readSession();
      if (session != null) {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(
          _cachePrefix + session.userId,
          jsonEncode(roadmap.toJson()),
        );
      }
      return roadmap;
    } on ApiException catch (error) {
      if (error.isUnauthorized) rethrow;
      final cached = await _readCache();
      if (cached != null) return cached.asCached();
      rethrow;
    }
  }

  Future<void> markLessonCompleteLocally(
    String lessonId,
    DateTime completedAt,
  ) async {
    final session = await _sessionStore.readSession();
    if (session == null) return;
    final preferences = await SharedPreferences.getInstance();
    final key = _cachePrefix + session.userId;
    final encoded = preferences.getString(key);
    if (encoded == null) return;
    try {
      final roadmap = Roadmap.fromJson(jsonDecode(encoded));
      final courses = roadmap.courses
          .map((course) {
            final lessons = course.lessons
                .map(
                  (lesson) => lesson.id == lessonId
                      ? RoadmapLesson(
                          id: lesson.id,
                          title: lesson.title,
                          summary: lesson.summary,
                          durationMin: lesson.durationMin,
                          position: lesson.position,
                          completedAt: completedAt,
                        )
                      : lesson,
                )
                .toList(growable: false);
            return RoadmapCourse(
              id: course.id,
              title: course.title,
              description: course.description,
              level: course.level,
              position: course.position,
              lessons: lessons,
            );
          })
          .toList(growable: false);
      final completedCount = courses.fold<int>(
        0,
        (total, course) =>
            total + course.lessons.where((lesson) => lesson.isComplete).length,
      );
      await preferences.setString(
        key,
        jsonEncode(
          Roadmap(
            courses: courses,
            completedLessonCount: completedCount,
          ).toJson(),
        ),
      );
    } on FormatException {
      await preferences.remove(key);
    } on TypeError {
      await preferences.remove(key);
    }
  }

  Future<Roadmap?> _readCache() async {
    final session = await _sessionStore.readSession();
    if (session == null) return null;
    final preferences = await SharedPreferences.getInstance();
    final cacheKey = _cachePrefix + session.userId;
    final encoded = preferences.getString(cacheKey);
    if (encoded == null) return null;
    try {
      return Roadmap.fromJson(jsonDecode(encoded));
    } on FormatException {
      await preferences.remove(cacheKey);
      return null;
    } on TypeError {
      await preferences.remove(cacheKey);
      return null;
    }
  }
}
