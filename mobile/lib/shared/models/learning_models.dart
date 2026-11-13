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
    required this.tier,
  });

  final String id;
  final String word;
  final String partOfSpeech;
  final String definition;
  final String example;
  final String level;
  final int tier;

  String get tierLabel => switch (tier) {
    1 => 'Tier 1 · everyday',
    3 => 'Tier 3 · specialist',
    _ => 'Tier 2 · academic',
  };

  factory VocabularyItem.fromJson(Object? json) {
    final map = _asMap(json);
    return VocabularyItem(
      id: map['id'] as String? ?? '',
      word: map['word'] as String? ?? '',
      partOfSpeech: map['partOfSpeech'] as String? ?? '',
      definition: map['definition'] as String? ?? '',
      example: map['example'] as String? ?? '',
      level: map['level'] as String? ?? '',
      tier: (map['tier'] as num?)?.toInt() ?? 2,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'word': word,
    'partOfSpeech': partOfSpeech,
    'definition': definition,
    'example': example,
    'level': level,
    'tier': tier,
  };
}

class VocabularyReview {
  const VocabularyReview({
    required this.item,
    required this.dueAt,
    required this.intervalDays,
    required this.repetitions,
    required this.lastGrade,
    required this.easeFactor,
    required this.lapses,
    required this.recallMode,
    required this.cloze,
    required this.source,
  });

  final VocabularyItem item;
  final DateTime dueAt;
  final int intervalDays;
  final int repetitions;
  final String? lastGrade;
  final double easeFactor;
  final int lapses;
  final String recallMode;
  final String? cloze;
  final String source;

  factory VocabularyReview.fromJson(Object? json) {
    final map = _asMap(json);
    return VocabularyReview(
      item: VocabularyItem.fromJson(map['item']),
      dueAt: DateTime.tryParse(map['dueAt'] as String? ?? '') ?? DateTime.now(),
      intervalDays: (map['intervalDays'] as num?)?.toInt() ?? 0,
      repetitions: (map['repetitions'] as num?)?.toInt() ?? 0,
      lastGrade: map['lastGrade'] as String?,
      easeFactor: (map['easeFactor'] as num?)?.toDouble() ?? 2.5,
      lapses: (map['lapses'] as num?)?.toInt() ?? 0,
      recallMode: map['recallMode'] as String? ?? 'definition',
      cloze: map['cloze'] as String?,
      source: map['source'] as String? ?? 'catalog',
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'item': item.toJson(),
    'dueAt': dueAt.toIso8601String(),
    'intervalDays': intervalDays,
    'repetitions': repetitions,
    'lastGrade': lastGrade,
    'easeFactor': easeFactor,
    'lapses': lapses,
    'recallMode': recallMode,
    'cloze': cloze,
    'source': source,
  };
}

class FillerUse {
  const FillerUse({
    required this.word,
    required this.count,
    required this.category,
  });

  final String word;
  final int count;
  final String category;

  factory FillerUse.fromJson(Object? json) {
    final map = _asMap(json);
    return FillerUse(
      word: map['word'] as String? ?? '',
      count: (map['count'] as num?)?.toInt() ?? 0,
      category: map['category'] as String? ?? 'hesitation',
    );
  }
}

class SpeakingFeedback {
  const SpeakingFeedback({
    required this.label,
    required this.wordCount,
    required this.uniqueWordCount,
    required this.wordsPerMinute,
    required this.articulationRate,
    required this.fillerCount,
    required this.fillers,
    required this.vocabularyVariety,
    required this.pauseCount,
    required this.longPauseCount,
    required this.pauseSeconds,
    required this.pauseRatio,
    required this.pauseNote,
    required this.wpmChange,
    required this.wpmTrend,
    required this.wpmTrendMessage,
    required this.pronunciationMessage,
    required this.nextStep,
  });

  final String label;
  final int wordCount;
  final int uniqueWordCount;
  final int wordsPerMinute;
  final int articulationRate;
  final int fillerCount;
  final List<FillerUse> fillers;
  final double vocabularyVariety;
  final int pauseCount;
  final int longPauseCount;
  final double pauseSeconds;
  final double pauseRatio;
  final String pauseNote;
  final int? wpmChange;
  final List<int> wpmTrend;
  final String wpmTrendMessage;
  final String pronunciationMessage;
  final String nextStep;

  factory SpeakingFeedback.fromJson(Object? json) {
    final map = _asMap(json);
    final pronunciation = _asMap(map['pronunciation']);
    final trend = _asMap(map['wpmTrend']);
    return SpeakingFeedback(
      label: map['label'] as String? ?? 'Practice estimate',
      wordCount: (map['wordCount'] as num?)?.toInt() ?? 0,
      uniqueWordCount: (map['uniqueWordCount'] as num?)?.toInt() ?? 0,
      wordsPerMinute: (map['wordsPerMinute'] as num?)?.toInt() ?? 0,
      articulationRate: (map['articulationRate'] as num?)?.toInt() ?? 0,
      fillerCount: (map['fillerCount'] as num?)?.toInt() ?? 0,
      fillers: (map['fillers'] as List<dynamic>? ?? const <dynamic>[])
          .map(FillerUse.fromJson)
          .toList(growable: false),
      vocabularyVariety: (map['vocabularyVariety'] as num?)?.toDouble() ?? 0,
      pauseCount: (map['pauseCount'] as num?)?.toInt() ?? 0,
      longPauseCount: (map['longPauseCount'] as num?)?.toInt() ?? 0,
      pauseSeconds: (map['pauseSeconds'] as num?)?.toDouble() ?? 0,
      pauseRatio: (map['pauseRatio'] as num?)?.toDouble() ?? 0,
      pauseNote:
          map['pauseNote'] as String? ??
          'Pause detection was not available for this session.',
      wpmChange: (trend['change'] as num?)?.toInt(),
      wpmTrend: (trend['points'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<num>()
          .map((value) => value.toInt())
          .toList(growable: false),
      wpmTrendMessage:
          trend['message'] as String? ??
          'Complete another session to see your pace trend.',
      pronunciationMessage:
          pronunciation['message'] as String? ??
          'Pronunciation scoring is unavailable.',
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
  const CoachScenario({
    required this.id,
    required this.title,
    required this.description,
    required this.opening,
  });

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
  const CoachTurn({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
  });

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
      turns: (map['turns'] as List<dynamic>? ?? const <dynamic>[])
          .map(CoachTurn.fromJson)
          .toList(growable: false),
      summary: map['summary'] as String?,
    );
  }
}

class CoachTurnReceipt {
  const CoachTurnReceipt({
    required this.turn,
    required this.turnsCount,
    required this.practiceCue,
    this.replyTurn,
    this.recast,
  });

  final CoachTurn turn;
  final CoachTurn? replyTurn;
  final String? recast;
  final int turnsCount;
  final String practiceCue;

  factory CoachTurnReceipt.fromJson(Object? json) {
    final map = _asMap(json);
    return CoachTurnReceipt(
      turn: CoachTurn.fromJson(map['turn']),
      replyTurn: map['replyTurn'] != null
          ? CoachTurn.fromJson(map['replyTurn'])
          : null,
      recast: map['recast'] as String?,
      turnsCount: (map['turnsCount'] as num?)?.toInt() ?? 0,
      practiceCue:
          map['practiceCue'] as String? ??
          'Add one clear detail to your response.',
    );
  }
}

class IeltsSection {
  const IeltsSection({
    required this.id,
    required this.title,
    required this.prompt,
    required this.preparationSeconds,
    required this.responseSeconds,
  });

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
  const IeltsMock({
    required this.id,
    required this.title,
    required this.description,
    required this.sections,
  });

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
      sections: (map['sections'] as List<dynamic>? ?? const <dynamic>[])
          .map(IeltsSection.fromJson)
          .toList(growable: false),
    );
  }
}

class IeltsAttemptReference {
  const IeltsAttemptReference({
    required this.id,
    required this.mockId,
    required this.status,
  });
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
  Set<String> get answeredSectionIds =>
      responses.map((response) => response.sectionId).toSet();

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
    required this.fluencyTrend,
    required this.fluencyWpmVariance,
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
  final List<int> fluencyTrend;
  final double? fluencyWpmVariance;
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
      vocabularyBaselineScore: (map['vocabularyBaselineScore'] as num?)
          ?.toInt(),
      vocabularyLatestScore: (map['vocabularyLatestScore'] as num?)?.toInt(),
      vocabularyScoreChange: (map['vocabularyScoreChange'] as num?)?.toInt(),
      fluencyBaselineWpm: (map['fluencyBaselineWpm'] as num?)?.toInt(),
      fluencyLatestWpm: (map['fluencyLatestWpm'] as num?)?.toInt(),
      fluencyScoreChange: (map['fluencyScoreChange'] as num?)?.toInt(),
      fluencyBaselineSessions: value('fluencyBaselineSessions'),
      fluencyTrend: (map['fluencyTrend'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<num>()
          .map((item) => item.toInt())
          .toList(growable: false),
      fluencyWpmVariance: (map['fluencyWpmVariance'] as num?)?.toDouble(),
      currentStreak: value('currentStreak'),
      longestStreak: value('longestStreak'),
      note:
          map['note'] as String? ??
          'Progress reflects completed practice only.',
    );
  }
}

class PlacementQuestion {
  const PlacementQuestion({
    required this.id,
    required this.prompt,
    required this.choices,
  });
  final String id;
  final String prompt;
  final List<String> choices;

  factory PlacementQuestion.fromJson(Object? json) {
    final map = _asMap(json);
    return PlacementQuestion(
      id: map['id'] as String? ?? '',
      prompt: map['prompt'] as String? ?? '',
      choices: (map['choices'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}

class PlacementResult {
  const PlacementResult({
    required this.score,
    required this.total,
    required this.baseline,
    required this.previousScore,
    required this.change,
    required this.label,
  });
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
      label:
          map['label'] as String? ??
          'Practice check, not a certified proficiency result.',
    );
  }
}

class HabitSnapshot {
  const HabitSnapshot({
    required this.currentDays,
    required this.longestDays,
    required this.reminderTime,
    required this.reminderDays,
    this.activeDates = const <String>[],
  });

  final int currentDays;
  final int longestDays;
  final String? reminderTime;
  final List<int> reminderDays;

  /// Recent practice days as `YYYY-MM-DD`, covering every activity type.
  final List<String> activeDates;

  factory HabitSnapshot.fromJson(Object? json) {
    final map = _asMap(json);
    return HabitSnapshot(
      currentDays: (map['currentDays'] as num?)?.toInt() ?? 0,
      longestDays: (map['longestDays'] as num?)?.toInt() ?? 0,
      reminderTime: map['reminderTime'] as String?,
      reminderDays: (map['reminderDays'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<num>()
          .map((value) => value.toInt())
          .toList(growable: false),
      activeDates:
          (map['activeDates'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(growable: false),
    );
  }
}

class EntitlementSnapshot {
  const EntitlementSnapshot({
    required this.plan,
    required this.premium,
    required this.productId,
    required this.expiresAt,
  });
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
  const ReferralSummary({
    required this.code,
    required this.redeemed,
    required this.referredCount,
    required this.reward,
  });
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

class ExposureLevel {
  const ExposureLevel({
    required this.level,
    required this.title,
    required this.description,
    required this.available,
    required this.sessionsCompleted,
    required this.sessionsRequired,
    required this.complete,
    required this.unlocked,
    required this.reason,
  });

  final int level;
  final String title;
  final String description;
  final bool available;
  final int sessionsCompleted;
  final int sessionsRequired;
  final bool complete;
  final bool unlocked;
  final String? reason;

  factory ExposureLevel.fromJson(Object? json) {
    final map = _asMap(json);
    return ExposureLevel(
      level: (map['level'] as num?)?.toInt() ?? 1,
      title: map['title'] as String? ?? 'Comfort practice',
      description: map['description'] as String? ?? '',
      available: map['available'] as bool? ?? false,
      sessionsCompleted: (map['sessionsCompleted'] as num?)?.toInt() ?? 0,
      sessionsRequired: (map['sessionsRequired'] as num?)?.toInt() ?? 3,
      complete: map['complete'] as bool? ?? false,
      unlocked: map['unlocked'] as bool? ?? false,
      reason: map['reason'] as String?,
    );
  }
}

class ExposureSummary {
  const ExposureSummary({required this.sessionsRequired, required this.levels});

  final int sessionsRequired;
  final List<ExposureLevel> levels;

  factory ExposureSummary.fromJson(Object? json) {
    final map = _asMap(json);
    return ExposureSummary(
      sessionsRequired: (map['sessionsRequired'] as num?)?.toInt() ?? 3,
      levels: (map['levels'] as List<dynamic>? ?? const <dynamic>[])
          .map(ExposureLevel.fromJson)
          .toList(growable: false),
    );
  }
}

class ShadowPassage {
  const ShadowPassage({
    required this.id,
    required this.title,
    required this.level,
    required this.targetWpm,
    required this.durationEstimateSec,
    required this.text,
    required this.focus,
    required this.chunks,
  });

  final String id;
  final String title;
  final String level;
  final int targetWpm;
  final int durationEstimateSec;
  final String text;
  final String focus;
  final List<String> chunks;

  factory ShadowPassage.fromJson(Object? json) {
    final map = _asMap(json);
    return ShadowPassage(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      level: map['level'] as String? ?? 'beginner',
      targetWpm: (map['targetWpm'] as num?)?.toInt() ?? 120,
      durationEstimateSec: (map['durationEstimateSec'] as num?)?.toInt() ?? 20,
      text: map['text'] as String? ?? '',
      focus: map['focus'] as String? ?? '',
      chunks: (map['chunks'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}

class ShadowFeedback {
  const ShadowFeedback({
    required this.paceDiagnosis,
    required this.prosodyTip,
    required this.nextStep,
  });

  final String paceDiagnosis;
  final String prosodyTip;
  final String nextStep;

  factory ShadowFeedback.fromJson(Object? json) {
    final map = _asMap(json);
    return ShadowFeedback(
      paceDiagnosis: map['paceDiagnosis'] as String? ?? '',
      prosodyTip: map['prosodyTip'] as String? ?? '',
      nextStep: map['nextStep'] as String? ?? '',
    );
  }
}

class ShadowAnalysisResult {
  const ShadowAnalysisResult({
    required this.passageId,
    required this.passageTitle,
    required this.level,
    required this.targetWpm,
    required this.actualWpm,
    required this.durationSeconds,
    required this.wordCount,
    required this.wordMatchPercent,
    required this.paceAlignmentPercent,
    required this.rhythmScore,
    required this.overallScore,
    required this.feedback,
  });

  final String passageId;
  final String passageTitle;
  final String level;
  final int targetWpm;
  final int actualWpm;
  final int durationSeconds;
  final int wordCount;
  final int wordMatchPercent;
  final int paceAlignmentPercent;
  final int? rhythmScore;
  final int overallScore;
  final ShadowFeedback feedback;

  factory ShadowAnalysisResult.fromJson(Object? json) {
    final map = _asMap(json);
    return ShadowAnalysisResult(
      passageId: map['passageId'] as String? ?? '',
      passageTitle: map['passageTitle'] as String? ?? '',
      level: map['level'] as String? ?? 'beginner',
      targetWpm: (map['targetWpm'] as num?)?.toInt() ?? 120,
      actualWpm: (map['actualWpm'] as num?)?.toInt() ?? 0,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      wordCount: (map['wordCount'] as num?)?.toInt() ?? 0,
      wordMatchPercent: (map['wordMatchPercent'] as num?)?.toInt() ?? 0,
      paceAlignmentPercent: (map['paceAlignmentPercent'] as num?)?.toInt() ?? 0,
      rhythmScore: (map['rhythmScore'] as num?)?.toInt(),
      overallScore: (map['overallScore'] as num?)?.toInt() ?? 0,
      feedback: ShadowFeedback.fromJson(map['feedback']),
    );
  }
}

class ContentVocabulary {
  const ContentVocabulary({
    required this.word,
    required this.definition,
    required this.partOfSpeech,
    required this.sampleSentence,
  });

  final String word;
  final String definition;
  final String partOfSpeech;
  final String sampleSentence;

  factory ContentVocabulary.fromJson(Object? json) {
    final map = _asMap(json);
    return ContentVocabulary(
      word: map['word'] as String? ?? '',
      definition: map['definition'] as String? ?? '',
      partOfSpeech: map['partOfSpeech'] as String? ?? 'word',
      sampleSentence: map['sampleSentence'] as String? ?? '',
    );
  }
}

class ContentQuestion {
  const ContentQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  factory ContentQuestion.fromJson(Object? json) {
    final map = _asMap(json);
    return ContentQuestion(
      id: map['id'] as String? ?? '',
      question: map['question'] as String? ?? '',
      options: (map['options'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(growable: false),
      correctIndex: (map['correctIndex'] as num?)?.toInt() ?? 0,
      explanation: map['explanation'] as String? ?? '',
    );
  }
}

class ContentOutputPrompt {
  const ContentOutputPrompt({
    required this.instruction,
    required this.requiredWordCount,
    required this.recommendedTargetWords,
    required this.sampleResponse,
  });

  final String instruction;
  final int requiredWordCount;
  final List<String> recommendedTargetWords;
  final String sampleResponse;

  factory ContentOutputPrompt.fromJson(Object? json) {
    final map = _asMap(json);
    return ContentOutputPrompt(
      instruction: map['instruction'] as String? ?? '',
      requiredWordCount: (map['requiredWordCount'] as num?)?.toInt() ?? 20,
      recommendedTargetWords:
          (map['recommendedTargetWords'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) => e.toString())
              .toList(growable: false),
      sampleResponse: map['sampleResponse'] as String? ?? '',
    );
  }
}

class ContentArticle {
  const ContentArticle({
    required this.id,
    required this.title,
    required this.level,
    required this.topic,
    required this.readingTimeMin,
    required this.wordCount,
    required this.summary,
    required this.content,
    required this.vocabulary,
    required this.questions,
    required this.outputPrompt,
  });

  final String id;
  final String title;
  final String level;
  final String topic;
  final int readingTimeMin;
  final int wordCount;
  final String summary;
  final String content;
  final List<ContentVocabulary> vocabulary;
  final List<ContentQuestion> questions;
  final ContentOutputPrompt outputPrompt;

  factory ContentArticle.fromJson(Object? json) {
    final map = _asMap(json);
    return ContentArticle(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Reading Article',
      level: map['level'] as String? ?? 'B1',
      topic: map['topic'] as String? ?? 'General',
      readingTimeMin: (map['readingTimeMin'] as num?)?.toInt() ?? 3,
      wordCount: (map['wordCount'] as num?)?.toInt() ?? 100,
      summary: map['summary'] as String? ?? '',
      content: map['content'] as String? ?? '',
      vocabulary: (map['vocabulary'] as List<dynamic>? ?? const <dynamic>[])
          .map(ContentVocabulary.fromJson)
          .toList(growable: false),
      questions: (map['questions'] as List<dynamic>? ?? const <dynamic>[])
          .map(ContentQuestion.fromJson)
          .toList(growable: false),
      outputPrompt: ContentOutputPrompt.fromJson(map['outputPrompt']),
    );
  }
}

class ArticleEvaluationResult {
  const ArticleEvaluationResult({
    required this.articleId,
    required this.wordCount,
    required this.sentenceCount,
    required this.targetWordsUsed,
    required this.targetWordsMissing,
    required this.mechanicsScore,
    required this.vocabularyScore,
    required this.overallScore,
    required this.strengths,
    required this.suggestions,
    required this.recast,
  });

  final String articleId;
  final int wordCount;
  final int sentenceCount;
  final List<String> targetWordsUsed;
  final List<String> targetWordsMissing;
  final int mechanicsScore;
  final int vocabularyScore;
  final int overallScore;
  final List<String> strengths;
  final List<String> suggestions;
  final String? recast;

  factory ArticleEvaluationResult.fromJson(Object? json) {
    final map = _asMap(json);
    return ArticleEvaluationResult(
      articleId: map['articleId'] as String? ?? '',
      wordCount: (map['wordCount'] as num?)?.toInt() ?? 0,
      sentenceCount: (map['sentenceCount'] as num?)?.toInt() ?? 1,
      targetWordsUsed:
          (map['targetWordsUsed'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) => e.toString())
              .toList(growable: false),
      targetWordsMissing:
          (map['targetWordsMissing'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) => e.toString())
              .toList(growable: false),
      mechanicsScore: (map['mechanicsScore'] as num?)?.toInt() ?? 0,
      vocabularyScore: (map['vocabularyScore'] as num?)?.toInt() ?? 0,
      overallScore: (map['overallScore'] as num?)?.toInt() ?? 0,
      strengths: (map['strengths'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(growable: false),
      suggestions: (map['suggestions'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(growable: false),
      recast: map['recast'] as String?,
    );
  }
}

class AffectiveAssessmentResult {
  const AffectiveAssessmentResult({
    required this.anxietyState,
    required this.shouldScaffold,
    required this.intervention,
    required this.confidenceScore,
    required this.latencyMs,
    required this.provider,
  });

  final String anxietyState;
  final bool shouldScaffold;
  final String intervention;
  final double confidenceScore;
  final int latencyMs;
  final String provider;

  factory AffectiveAssessmentResult.fromJson(Object? json) {
    final map = _asMap(json);
    return AffectiveAssessmentResult(
      anxietyState: map['anxietyState'] as String? ?? 'calm',
      shouldScaffold: map['shouldScaffold'] as bool? ?? false,
      intervention: map['intervention'] as String? ?? 'none',
      confidenceScore: (map['confidenceScore'] as num?)?.toDouble() ?? 0.8,
      latencyMs: (map['latencyMs'] as num?)?.toInt() ?? 0,
      provider: map['provider'] as String? ?? 'heuristic-calibrated',
    );
  }
}

class CefrCalibrationResult {
  const CefrCalibrationResult({
    required this.calibratedCefr,
    required this.syntacticComplexity,
    required this.lexicalRange,
    required this.adaptiveAction,
    required this.latencyMs,
    required this.provider,
  });

  final String calibratedCefr;
  final double syntacticComplexity;
  final double lexicalRange;
  final String adaptiveAction;
  final int latencyMs;
  final String provider;

  factory CefrCalibrationResult.fromJson(Object? json) {
    final map = _asMap(json);
    return CefrCalibrationResult(
      calibratedCefr: map['calibratedCefr'] as String? ?? 'B1',
      syntacticComplexity:
          (map['syntacticComplexity'] as num?)?.toDouble() ?? 0.7,
      lexicalRange: (map['lexicalRange'] as num?)?.toDouble() ?? 0.7,
      adaptiveAction: map['adaptiveAction'] as String? ?? 'maintain_level',
      latencyMs: (map['latencyMs'] as num?)?.toInt() ?? 0,
      provider: map['provider'] as String? ?? 'heuristic-calibrated',
    );
  }
}

class PhonemeItem {
  const PhonemeItem({
    required this.word,
    required this.ipa,
    required this.meaning,
    required this.audioSampleText,
  });

  final String word;
  final String ipa;
  final String meaning;
  final String audioSampleText;

  factory PhonemeItem.fromJson(Object? json) {
    final map = _asMap(json);
    return PhonemeItem(
      word: map['word'] as String? ?? '',
      ipa: map['ipa'] as String? ?? '',
      meaning: map['meaning'] as String? ?? '',
      audioSampleText: map['audioSampleText'] as String? ?? '',
    );
  }
}

class ArticulatoryGuide {
  const ArticulatoryGuide({
    required this.tonguePlacement,
    required this.lipShape,
    required this.voicing,
    required this.commonPitfall,
  });

  final String tonguePlacement;
  final String lipShape;
  final String voicing;
  final String commonPitfall;

  factory ArticulatoryGuide.fromJson(Object? json) {
    final map = _asMap(json);
    return ArticulatoryGuide(
      tonguePlacement: map['tonguePlacement'] as String? ?? '',
      lipShape: map['lipShape'] as String? ?? '',
      voicing: map['voicing'] as String? ?? '',
      commonPitfall: map['commonPitfall'] as String? ?? '',
    );
  }
}

class MinimalPairSet {
  const MinimalPairSet({
    required this.id,
    required this.title,
    required this.phoneticContrast,
    required this.category,
    required this.level,
    required this.wordA,
    required this.wordB,
    required this.articulatoryGuide,
    required this.sentenceDrill,
  });

  final String id;
  final String title;
  final String phoneticContrast;
  final String category;
  final String level;
  final PhonemeItem wordA;
  final PhonemeItem wordB;
  final ArticulatoryGuide articulatoryGuide;
  final String sentenceDrill;

  factory MinimalPairSet.fromJson(Object? json) {
    final map = _asMap(json);
    return MinimalPairSet(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      phoneticContrast: map['phoneticContrast'] as String? ?? '',
      category: map['category'] as String? ?? 'consonant',
      level: map['level'] as String? ?? 'A1',
      wordA: PhonemeItem.fromJson(map['wordA']),
      wordB: PhonemeItem.fromJson(map['wordB']),
      articulatoryGuide: ArticulatoryGuide.fromJson(map['articulatoryGuide']),
      sentenceDrill: map['sentenceDrill'] as String? ?? '',
    );
  }
}

class PhonemeAnalysisResult {
  const PhonemeAnalysisResult({
    required this.pairId,
    required this.targetChoice,
    required this.targetWord,
    required this.spokenTranscript,
    required this.accuracyScore,
    required this.isAccurate,
    required this.confusedWithCounterpart,
    required this.phonemeFeedback,
    required this.articulatoryTip,
    required this.awardedXp,
  });

  final String pairId;
  final String targetChoice;
  final String targetWord;
  final String spokenTranscript;
  final double accuracyScore;
  final bool isAccurate;
  final bool confusedWithCounterpart;
  final String phonemeFeedback;
  final String articulatoryTip;
  final int awardedXp;

  factory PhonemeAnalysisResult.fromJson(Object? json) {
    final map = _asMap(json);
    return PhonemeAnalysisResult(
      pairId: map['pairId'] as String? ?? '',
      targetChoice: map['targetChoice'] as String? ?? 'A',
      targetWord: map['targetWord'] as String? ?? '',
      spokenTranscript: map['spokenTranscript'] as String? ?? '',
      accuracyScore: (map['accuracyScore'] as num?)?.toDouble() ?? 0.0,
      isAccurate: map['isAccurate'] as bool? ?? false,
      confusedWithCounterpart: map['confusedWithCounterpart'] as bool? ?? false,
      phonemeFeedback: map['phonemeFeedback'] as String? ?? '',
      articulatoryTip: map['articulatoryTip'] as String? ?? '',
      awardedXp: (map['awardedXp'] as num?)?.toInt() ?? 0,
    );
  }
}

class MasteryProfile {
  const MasteryProfile({
    required this.userId,
    required this.fluencyXp,
    required this.lexicalXp,
    required this.acousticXp,
    required this.interactionXp,
    required this.totalXp,
    required this.level,
    required this.rankTitle,
    required this.freezeTokens,
    required this.levelProgressPercent,
    required this.nextLevelXpRequired,
    required this.perk,
  });

  final String userId;
  final int fluencyXp;
  final int lexicalXp;
  final int acousticXp;
  final int interactionXp;
  final int totalXp;
  final int level;
  final String rankTitle;
  final int freezeTokens;
  final int levelProgressPercent;
  final int nextLevelXpRequired;
  final String perk;

  factory MasteryProfile.fromJson(Object? json) {
    final map = _asMap(json);
    return MasteryProfile(
      userId: map['userId'] as String? ?? '',
      fluencyXp: (map['fluencyXp'] as num?)?.toInt() ?? 0,
      lexicalXp: (map['lexicalXp'] as num?)?.toInt() ?? 0,
      acousticXp: (map['acousticXp'] as num?)?.toInt() ?? 0,
      interactionXp: (map['interactionXp'] as num?)?.toInt() ?? 0,
      totalXp: (map['totalXp'] as num?)?.toInt() ?? 0,
      level: (map['level'] as num?)?.toInt() ?? 1,
      rankTitle: map['rankTitle'] as String? ?? 'Apprentice',
      freezeTokens: (map['freezeTokens'] as num?)?.toInt() ?? 0,
      levelProgressPercent: (map['levelProgressPercent'] as num?)?.toInt() ?? 0,
      nextLevelXpRequired: (map['nextLevelXpRequired'] as num?)?.toInt() ?? 0,
      perk: map['perk'] as String? ?? '',
    );
  }
}

Map<String, Object?> _asMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return value.cast<String, Object?>();
  return const <String, Object?>{};
}
