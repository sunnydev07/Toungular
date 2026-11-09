enum RoadmapSource { live, cached }

enum Proficiency {
  beginner,
  elementary,
  intermediate,
  upperIntermediate,
  advanced;

  String get label => switch (this) {
        Proficiency.beginner => 'Beginner',
        Proficiency.elementary => 'Elementary',
        Proficiency.intermediate => 'Intermediate',
        Proficiency.upperIntermediate => 'Upper intermediate',
        Proficiency.advanced => 'Advanced',
      };

  static Proficiency fromValue(Object? value) => Proficiency.values.firstWhere(
        (level) => level.name == value,
        orElse: () => Proficiency.beginner,
      );
}

class LearnerProfile {
  const LearnerProfile({
    required this.userId,
    required this.email,
    required this.goals,
    required this.proficiency,
    required this.dailyMinutes,
    required this.timezone,
    required this.ieltsIntent,
  });

  final String userId;
  final String email;
  final List<String> goals;
  final Proficiency proficiency;
  final int dailyMinutes;
  final String timezone;
  final bool ieltsIntent;

  bool get needsOnboarding => goals.isEmpty;

  factory LearnerProfile.fromJson(Object? json) {
    final map = _asMap(json);
    return LearnerProfile(
      userId: map['userId'] as String? ?? '',
      email: map['email'] as String? ?? '',
      goals: (map['goals'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
      proficiency: Proficiency.fromValue(map['proficiency']),
      dailyMinutes: (map['dailyMinutes'] as num?)?.toInt() ?? 15,
      timezone: map['timezone'] as String? ?? 'UTC',
      ieltsIntent: map['ieltsIntent'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'userId': userId,
        'email': email,
        'goals': goals,
        'proficiency': proficiency.name,
        'dailyMinutes': dailyMinutes,
        'timezone': timezone,
        'ieltsIntent': ieltsIntent,
      };
}

class LearnerSession {
  const LearnerSession({
    required this.userId,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
    required this.profile,
  });

  final String userId;
  final String email;
  final String accessToken;
  final String refreshToken;
  final LearnerProfile profile;

  LearnerSession withProfile(LearnerProfile value) => LearnerSession(
        userId: userId,
        email: email,
        accessToken: accessToken,
        refreshToken: refreshToken,
        profile: value,
      );

  factory LearnerSession.fromAuthData(Object? json) {
    final map = _asMap(json);
    final user = _asMap(map['user']);
    return LearnerSession(
      userId: user['id'] as String? ?? '',
      email: user['email'] as String? ?? '',
      accessToken: map['accessToken'] as String? ?? '',
      refreshToken: map['refreshToken'] as String? ?? '',
      profile: LearnerProfile.fromJson(map['profile']),
    );
  }

  factory LearnerSession.fromJson(Object? json) {
    final map = _asMap(json);
    return LearnerSession(
      userId: map['userId'] as String? ?? '',
      email: map['email'] as String? ?? '',
      accessToken: map['accessToken'] as String? ?? '',
      refreshToken: map['refreshToken'] as String? ?? '',
      profile: LearnerProfile.fromJson(map['profile']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'userId': userId,
        'email': email,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'profile': profile.toJson(),
      };
}

class RoadmapLesson {
  const RoadmapLesson({
    required this.id,
    required this.title,
    required this.summary,
    required this.durationMin,
    required this.position,
    required this.completedAt,
  });

  final String id;
  final String title;
  final String summary;
  final int durationMin;
  final int position;
  final DateTime? completedAt;

  bool get isComplete => completedAt != null;

  factory RoadmapLesson.fromJson(Object? json) {
    final map = _asMap(json);
    final completed = map['completedAt'] as String?;
    return RoadmapLesson(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'English practice',
      summary: map['summary'] as String? ?? '',
      durationMin: (map['durationMin'] as num?)?.toInt() ?? 5,
      position: (map['position'] as num?)?.toInt() ?? 0,
      completedAt: completed == null ? null : DateTime.tryParse(completed),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'title': title,
        'summary': summary,
        'durationMin': durationMin,
        'position': position,
        'completedAt': completedAt?.toIso8601String(),
      };
}

class RoadmapCourse {
  const RoadmapCourse({
    required this.id,
    required this.title,
    required this.description,
    required this.level,
    required this.position,
    required this.lessons,
  });

  final String id;
  final String title;
  final String description;
  final String level;
  final int position;
  final List<RoadmapLesson> lessons;

  RoadmapLesson? get nextLesson {
    for (final lesson in lessons) {
      if (!lesson.isComplete) return lesson;
    }
    return null;
  }

  factory RoadmapCourse.fromJson(Object? json) {
    final map = _asMap(json);
    return RoadmapCourse(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Course',
      description: map['description'] as String? ?? '',
      level: map['level'] as String? ?? '',
      position: (map['position'] as num?)?.toInt() ?? 0,
      lessons: (map['lessons'] as List<dynamic>? ?? const <dynamic>[])
          .map(RoadmapLesson.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'title': title,
        'description': description,
        'level': level,
        'position': position,
        'lessons': lessons.map((lesson) => lesson.toJson()).toList(),
      };
}

class Roadmap {
  const Roadmap({
    required this.courses,
    required this.completedLessonCount,
    this.source = RoadmapSource.live,
  });

  final List<RoadmapCourse> courses;
  final int completedLessonCount;
  final RoadmapSource source;

  RoadmapLesson? get nextLesson {
    for (final course in courses) {
      final lesson = course.nextLesson;
      if (lesson != null) return lesson;
    }
    return null;
  }

  Roadmap asCached() => Roadmap(
        courses: courses,
        completedLessonCount: completedLessonCount,
        source: RoadmapSource.cached,
      );

  factory Roadmap.fromJson(Object? json) {
    final map = _asMap(json);
    return Roadmap(
      courses: (map['courses'] as List<dynamic>? ?? const <dynamic>[])
          .map(RoadmapCourse.fromJson)
          .toList(growable: false),
      completedLessonCount: (map['completedLessonCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'courses': courses.map((course) => course.toJson()).toList(),
        'completedLessonCount': completedLessonCount,
      };
}

class LessonContent {
  const LessonContent({
    required this.id,
    required this.courseTitle,
    required this.title,
    required this.summary,
    required this.content,
    required this.durationMin,
    required this.completedAt,
  });

  final String id;
  final String courseTitle;
  final String title;
  final String summary;
  final String content;
  final int durationMin;
  final DateTime? completedAt;

  factory LessonContent.fromJson(Object? json) {
    final map = _asMap(json);
    final course = _asMap(map['course']);
    final completed = map['completedAt'] as String?;
    return LessonContent(
      id: map['id'] as String? ?? '',
      courseTitle: course['title'] as String? ?? 'English practice',
      title: map['title'] as String? ?? 'Practice lesson',
      summary: map['summary'] as String? ?? '',
      content: map['content'] as String? ?? '',
      durationMin: (map['durationMin'] as num?)?.toInt() ?? 5,
      completedAt: completed == null ? null : DateTime.tryParse(completed),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'course': <String, Object?>{'title': courseTitle},
        'title': title,
        'summary': summary,
        'content': content,
        'durationMin': durationMin,
        'completedAt': completedAt?.toIso8601String(),
      };
}

class VocabularyItem {
  const VocabularyItem({
    required this.id,
    required this.word,
    required this.partOfSpeech,
    required this.definition,
    required this.example,
    required this.level,
  });

  final String id;
  final String word;
  final String partOfSpeech;
  final String definition;
  final String example;
  final String level;

  factory VocabularyItem.fromJson(Object? json) {
    final map = _asMap(json);
    return VocabularyItem(
      id: map['id'] as String? ?? '',
      word: map['word'] as String? ?? '',
      partOfSpeech: map['partOfSpeech'] as String? ?? '',
      definition: map['definition'] as String? ?? '',
      example: map['example'] as String? ?? '',
      level: map['level'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'word': word,
        'partOfSpeech': partOfSpeech,
        'definition': definition,
        'example': example,
        'level': level,
      };
}

class VocabularyReview {
  const VocabularyReview({
    required this.item,
    required this.dueAt,
    required this.intervalDays,
    required this.repetitions,
    required this.lastGrade,
  });

  final VocabularyItem item;
  final DateTime dueAt;
  final int intervalDays;
  final int repetitions;
  final String? lastGrade;

  factory VocabularyReview.fromJson(Object? json) {
    final map = _asMap(json);
    return VocabularyReview(
      item: VocabularyItem.fromJson(map['item']),
      dueAt: DateTime.tryParse(map['dueAt'] as String? ?? '') ?? DateTime.now(),
      intervalDays: (map['intervalDays'] as num?)?.toInt() ?? 0,
      repetitions: (map['repetitions'] as num?)?.toInt() ?? 0,
      lastGrade: map['lastGrade'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'item': item.toJson(),
        'dueAt': dueAt.toIso8601String(),
        'intervalDays': intervalDays,
        'repetitions': repetitions,
        'lastGrade': lastGrade,
      };
}

class SpeakingFeedback {
  const SpeakingFeedback({
    required this.label,
    required this.wordCount,
    required this.wordsPerMinute,
    required this.fillerCount,
    required this.vocabularyVariety,
    required this.pronunciationMessage,
    required this.nextStep,
  });

  final String label;
  final int wordCount;
  final int wordsPerMinute;
  final int fillerCount;
  final double vocabularyVariety;
  final String pronunciationMessage;
  final String nextStep;

  factory SpeakingFeedback.fromJson(Object? json) {
    final map = _asMap(json);
    final pronunciation = _asMap(map['pronunciation']);
    return SpeakingFeedback(
      label: map['label'] as String? ?? 'Practice estimate',
      wordCount: (map['wordCount'] as num?)?.toInt() ?? 0,
      wordsPerMinute: (map['wordsPerMinute'] as num?)?.toInt() ?? 0,
      fillerCount: (map['fillerCount'] as num?)?.toInt() ?? 0,
      vocabularyVariety: (map['vocabularyVariety'] as num?)?.toDouble() ?? 0,
      pronunciationMessage: pronunciation['message'] as String? ?? 'Pronunciation scoring is unavailable.',
      nextStep: map['nextStep'] as String? ?? 'Try another short response.',
    );
  }
}

class SpeakingSessionSummary {
  const SpeakingSessionSummary({
    required this.id,
    required this.type,
    required this.status,
    required this.prompt,
    required this.transcript,
    required this.startedAt,
    required this.completedAt,
    this.feedback,
  });

  final String id;
  final String type;
  final String status;
  final String prompt;
  final String? transcript;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final SpeakingFeedback? feedback;

  factory SpeakingSessionSummary.fromJson(Object? json) {
    final map = _asMap(json);
    final feedback = map['feedback'];
    return SpeakingSessionSummary(
      id: map['id'] as String? ?? '',
      type: map['type'] as String? ?? 'prompt',
      status: map['status'] as String? ?? 'draft',
      prompt: map['prompt'] as String? ?? '',
      transcript: map['transcript'] as String?,
      startedAt: DateTime.tryParse(map['startedAt'] as String? ?? ''),
      completedAt: DateTime.tryParse(map['completedAt'] as String? ?? ''),
      feedback: feedback == null ? null : SpeakingFeedback.fromJson(feedback),
    );
  }
}

class CoachScenario {
  const CoachScenario({required this.id, required this.title, required this.description, required this.opening});

  final String id;
  final String title;
  final String description;
  final String opening;

  factory CoachScenario.fromJson(Object? json) {
    final map = _asMap(json);
    return CoachScenario(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Practice scenario',
      description: map['description'] as String? ?? '',
      opening: map['opening'] as String? ?? '',
    );
  }
}

class CoachTurn {
  const CoachTurn({required this.id, required this.role, required this.text, required this.createdAt});

  final String id;
  final String role;
  final String text;
  final DateTime? createdAt;

  factory CoachTurn.fromJson(Object? json) {
    final map = _asMap(json);
    return CoachTurn(
      id: map['id'] as String? ?? '',
      role: map['role'] as String? ?? 'learner',
      text: map['text'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
    );
  }
}

class CoachConversation {
  const CoachConversation({
    required this.id,
    required this.scenarioId,
    required this.status,
    required this.scenario,
    required this.turns,
    this.summary,
  });

  final String id;
  final String scenarioId;
  final String status;
  final CoachScenario scenario;
  final List<CoachTurn> turns;
  final String? summary;

  factory CoachConversation.fromJson(Object? json) {
    final map = _asMap(json);
    return CoachConversation(
      id: map['id'] as String? ?? '',
      scenarioId: map['scenarioId'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
      scenario: CoachScenario.fromJson(map['scenario']),
      turns: (map['turns'] as List<dynamic>? ?? const <dynamic>[]).map(CoachTurn.fromJson).toList(growable: false),
      summary: map['summary'] as String?,
    );
  }
}

class CoachTurnReceipt {
  const CoachTurnReceipt({required this.turn, required this.turnsCount, required this.practiceCue});

  final CoachTurn turn;
  final int turnsCount;
  final String practiceCue;

  factory CoachTurnReceipt.fromJson(Object? json) {
    final map = _asMap(json);
    return CoachTurnReceipt(
      turn: CoachTurn.fromJson(map['turn']),
      turnsCount: (map['turnsCount'] as num?)?.toInt() ?? 0,
      practiceCue: map['practiceCue'] as String? ?? 'Add one clear detail to your response.',
    );
  }
}

class IeltsSection {
  const IeltsSection({required this.id, required this.title, required this.prompt, required this.preparationSeconds, required this.responseSeconds});

  final String id;
  final String title;
  final String prompt;
  final int preparationSeconds;
  final int responseSeconds;

  factory IeltsSection.fromJson(Object? json) {
    final map = _asMap(json);
    return IeltsSection(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Speaking section',
      prompt: map['prompt'] as String? ?? '',
      preparationSeconds: (map['preparationSeconds'] as num?)?.toInt() ?? 0,
      responseSeconds: (map['responseSeconds'] as num?)?.toInt() ?? 60,
    );
  }
}

class IeltsMock {
  const IeltsMock({required this.id, required this.title, required this.description, required this.sections});

  final String id;
  final String title;
  final String description;
  final List<IeltsSection> sections;

  factory IeltsMock.fromJson(Object? json) {
    final map = _asMap(json);
    return IeltsMock(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Speaking practice',
      description: map['description'] as String? ?? '',
      sections: (map['sections'] as List<dynamic>? ?? const <dynamic>[]).map(IeltsSection.fromJson).toList(growable: false),
    );
  }
}

class IeltsAttemptReference {
  const IeltsAttemptReference({required this.id, required this.mockId, required this.status});
  final String id;
  final String mockId;
  final String status;

  factory IeltsAttemptReference.fromJson(Object? json) {
    final map = _asMap(json);
    return IeltsAttemptReference(
      id: map['id'] as String? ?? '',
      mockId: map['mockId'] as String? ?? '',
      status: map['status'] as String? ?? 'in_progress',
    );
  }
}

class IeltsAttemptRecord {
  const IeltsAttemptRecord({
    required this.id,
    required this.mockId,
    required this.status,
    required this.startedAt,
    required this.finishedAt,
    required this.feedback,
    required this.responses,
  });

  final String id;
  final String mockId;
  final String status;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? feedback;
  final List<IeltsSavedResponse> responses;

  bool get isInProgress => status == 'in_progress';
  Set<String> get answeredSectionIds => responses.map((response) => response.sectionId).toSet();

  factory IeltsAttemptRecord.fromJson(Object? json) {
    final map = _asMap(json);
    return IeltsAttemptRecord(
      id: map['id'] as String? ?? '',
      mockId: map['mockId'] as String? ?? '',
      status: map['status'] as String? ?? 'unknown',
      startedAt: DateTime.tryParse(map['startedAt'] as String? ?? ''),
      finishedAt: DateTime.tryParse(map['finishedAt'] as String? ?? ''),
      feedback: map['feedback'] as String?,
      responses: (map['responses'] as List<dynamic>? ?? const <dynamic>[])
          .map(IeltsSavedResponse.fromJson)
          .toList(growable: false),
    );
  }
}

class IeltsSavedResponse {
  const IeltsSavedResponse({required this.sectionId, required this.transcript});

  final String sectionId;
  final String? transcript;

  factory IeltsSavedResponse.fromJson(Object? json) {
    final map = _asMap(json);
    return IeltsSavedResponse(
      sectionId: map['sectionId'] as String? ?? '',
      transcript: map['transcript'] as String?,
    );
  }
}

class ProgressSummary {
  const ProgressSummary({
    required this.lessonsCompleted,
    required this.vocabularyItemsReviewed,
    required this.vocabularyRecallRepetitions,
    required this.speakingSessionsCompleted,
    required this.vocabularyBaselineScore,
    required this.vocabularyLatestScore,
    required this.vocabularyScoreChange,
    required this.fluencyBaselineWpm,
    required this.fluencyLatestWpm,
    required this.fluencyScoreChange,
    required this.fluencyBaselineSessions,
    required this.currentStreak,
    required this.longestStreak,
    required this.note,
  });

  final int lessonsCompleted;
  final int vocabularyItemsReviewed;
  final int vocabularyRecallRepetitions;
  final int speakingSessionsCompleted;
  final int? vocabularyBaselineScore;
  final int? vocabularyLatestScore;
  final int? vocabularyScoreChange;
  final int? fluencyBaselineWpm;
  final int? fluencyLatestWpm;
  final int? fluencyScoreChange;
  final int fluencyBaselineSessions;
  final int currentStreak;
  final int longestStreak;
  final String note;

  factory ProgressSummary.fromJson(Object? json) {
    final map = _asMap(json);
    int value(String key) => (map[key] as num?)?.toInt() ?? 0;
    return ProgressSummary(
      lessonsCompleted: value('lessonsCompleted'),
      vocabularyItemsReviewed: value('vocabularyItemsReviewed'),
      vocabularyRecallRepetitions: value('vocabularyRecallRepetitions'),
      speakingSessionsCompleted: value('speakingSessionsCompleted'),
      vocabularyBaselineScore: (map['vocabularyBaselineScore'] as num?)?.toInt(),
      vocabularyLatestScore: (map['vocabularyLatestScore'] as num?)?.toInt(),
      vocabularyScoreChange: (map['vocabularyScoreChange'] as num?)?.toInt(),
      fluencyBaselineWpm: (map['fluencyBaselineWpm'] as num?)?.toInt(),
      fluencyLatestWpm: (map['fluencyLatestWpm'] as num?)?.toInt(),
      fluencyScoreChange: (map['fluencyScoreChange'] as num?)?.toInt(),
      fluencyBaselineSessions: value('fluencyBaselineSessions'),
      currentStreak: value('currentStreak'),
      longestStreak: value('longestStreak'),
      note: map['note'] as String? ?? 'Progress reflects completed practice only.',
    );
  }
}

class PlacementQuestion {
  const PlacementQuestion({required this.id, required this.prompt, required this.choices});
  final String id;
  final String prompt;
  final List<String> choices;

  factory PlacementQuestion.fromJson(Object? json) {
    final map = _asMap(json);
    return PlacementQuestion(
      id: map['id'] as String? ?? '',
      prompt: map['prompt'] as String? ?? '',
      choices: (map['choices'] as List<dynamic>? ?? const <dynamic>[]).whereType<String>().toList(growable: false),
    );
  }
}

class PlacementResult {
  const PlacementResult({required this.score, required this.total, required this.baseline, required this.previousScore, required this.change, required this.label});
  final int score;
  final int total;
  final bool baseline;
  final int? previousScore;
  final int? change;
  final String label;

  factory PlacementResult.fromJson(Object? json) {
    final map = _asMap(json);
    return PlacementResult(
      score: (map['score'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 20,
      baseline: map['baseline'] as bool? ?? false,
      previousScore: (map['previousScore'] as num?)?.toInt(),
      change: (map['change'] as num?)?.toInt(),
      label: map['label'] as String? ?? 'Practice check, not a certified proficiency result.',
    );
  }
}

class HabitSnapshot {
  const HabitSnapshot({
    required this.currentDays,
    required this.longestDays,
    required this.reminderTime,
    required this.reminderDays,
  });

  final int currentDays;
  final int longestDays;
  final String? reminderTime;
  final List<int> reminderDays;

  factory HabitSnapshot.fromJson(Object? json) {
    final map = _asMap(json);
    return HabitSnapshot(
      currentDays: (map['currentDays'] as num?)?.toInt() ?? 0,
      longestDays: (map['longestDays'] as num?)?.toInt() ?? 0,
      reminderTime: map['reminderTime'] as String?,
      reminderDays: (map['reminderDays'] as List<dynamic>? ?? const <dynamic>[]).whereType<num>().map((value) => value.toInt()).toList(growable: false),
    );
  }
}

class EntitlementSnapshot {
  const EntitlementSnapshot({required this.plan, required this.premium, required this.productId, required this.expiresAt});
  final String plan;
  final bool premium;
  final String? productId;
  final DateTime? expiresAt;

  factory EntitlementSnapshot.fromJson(Object? json) {
    final map = _asMap(json);
    return EntitlementSnapshot(
      plan: map['plan'] as String? ?? 'free',
      premium: map['premium'] as bool? ?? false,
      productId: map['productId'] as String?,
      expiresAt: DateTime.tryParse(map['expiresAt'] as String? ?? ''),
    );
  }
}

class ReferralSummary {
  const ReferralSummary({required this.code, required this.redeemed, required this.referredCount, required this.reward});
  final String code;
  final bool redeemed;
  final int referredCount;
  final String reward;

  factory ReferralSummary.fromJson(Object? json) {
    final map = _asMap(json);
    return ReferralSummary(
      code: map['code'] as String? ?? '',
      redeemed: map['redeemed'] as bool? ?? false,
      referredCount: (map['referredCount'] as num?)?.toInt() ?? 0,
      reward: map['reward'] as String? ?? 'No reward is configured yet.',
    );
  }
}

Map<String, Object?> _asMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return value.cast<String, Object?>();
  return const <String, Object?>{};
}
