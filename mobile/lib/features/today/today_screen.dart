import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/toungular_theme.dart';
import '../../shared/models/learning_models.dart';
import '../auth/session_controller.dart';
import '../home/roadmap_repository.dart';
import '../progress/progress_repository.dart';
import '../speaking/speaking_repository.dart';
import '../vocabulary/vocabulary_repository.dart';
import 'week_activity.dart';

const _weekTarget = 5;

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key, this.onOpenPractice});

  /// Passed by HomeShell so "All practice" switches tabs without a global provider.
  final VoidCallback? onOpenPractice;

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  Future<void> _refresh() async {
    ref.invalidate(roadmapProvider);
    ref.invalidate(streakProvider);
    ref.invalidate(speakingHistoryProvider);
    ref.invalidate(dueVocabularyProvider);
    try {
      await ref.read(roadmapProvider.future);
    } catch (_) {
      // The error card below reports the recoverable failure.
    }
    await Future.wait<void>(<Future<void>>[
      _settle(ref.read(streakProvider.future)),
      _settle(ref.read(speakingHistoryProvider.future)),
      _settle(ref.read(dueVocabularyProvider.future)),
    ]);
  }

  Future<void> _settle(Future<Object?> request) async {
    try {
      await request;
    } catch (_) {
      // The secondary cards fall back to their empty state.
    }
  }

  Future<void> _signOut() async {
    await ref.read(sessionControllerProvider.notifier).signOut();
    if (mounted) context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final email = session.session?.profile.email ?? '';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ref
              .watch(roadmapProvider)
              .when(
                loading: () => const _Skeleton(),
                error: (error, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(ToungularSpace.l),
                  children: <Widget>[
                    if (error is ApiException && error.isUnauthorized)
                      _MessageCard(
                        title: 'Your session ended',
                        body: 'Sign in again to sync your learning path.',
                        action: OutlinedButton(
                          onPressed: _signOut,
                          child: const Text('Sign in again'),
                        ),
                      )
                    else
                      _MessageCard(
                        title: 'Your path is unavailable',
                        body: 'Connect to Toungular to load your plan. Your account remains saved on this device.',
                        action: OutlinedButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                      ),
                  ],
                ),
                data: (roadmap) => _content(
                  context,
                  _TodayData(
                    roadmap: roadmap,
                    streak: ref.watch(streakProvider).value,
                    history:
                        ref.watch(speakingHistoryProvider).value ??
                        const <SpeakingSessionSummary>[],
                    due:
                        ref.watch(dueVocabularyProvider).value ??
                        const <VocabularyReview>[],
                  ),
                  email,
                ),
              ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, _TodayData data, String email) {
    final roadmap = data.roadmap;
    final lesson = roadmap.nextLesson;
    RoadmapCourse? course;
    if (lesson != null) {
      for (final candidate in roadmap.courses) {
        if (candidate.lessons.any((item) => item.id == lesson.id)) {
          course = candidate;
          break;
        }
      }
    }

    final week = weekActivity(
      <DateTime?>[
        ...roadmap.courses.expand(
          (item) => item.lessons.map((lesson) => lesson.completedAt),
        ),
        ...data.history.map((session) => session.completedAt),
      ],
      DateTime.now(),
      target: _weekTarget,
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        ToungularSpace.l,
        ToungularSpace.s,
        ToungularSpace.l,
        ToungularSpace.xl,
      ),
      children: <Widget>[
        _GreetingRow(email: email, streak: data.streak?.currentDays ?? 0),
        const SizedBox(height: ToungularSpace.m),
        if (roadmap.source == RoadmapSource.cached)
          Padding(
            padding: const EdgeInsets.only(bottom: ToungularSpace.s),
            child: Text(
              'Showing your saved learning path. Pull down to sync when you are online.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        if (lesson == null || course == null)
          _MessageCard(
            title: 'You finished the path',
            body:
                'Every lesson is complete. ${roadmap.completedLessonCount} lessons done — keep the habit going.',
            action: Wrap(
              spacing: ToungularSpace.s,
              children: <Widget>[
                OutlinedButton(
                  onPressed: () => context.push('/vocabulary'),
                  child: const Text('Review vocabulary'),
                ),
                FilledButton(
                  onPressed: () => context.push('/speaking'),
                  child: const Text('Start speaking'),
                ),
              ],
            ),
          )
        else
          _HeroCard(course: course, lesson: lesson),
        const SizedBox(height: ToungularSpace.m),
        _GoalCard(week: week),
        const SizedBox(height: ToungularSpace.l),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Practice now',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton(
              onPressed: widget.onOpenPractice,
              child: const Text('All practice'),
            ),
          ],
        ),
        const SizedBox(height: ToungularSpace.xs),
        _PracticeTiles(dueCount: data.due.length),
        const SizedBox(height: ToungularSpace.m),
        _WeekCard(week: week),
      ],
    );
  }
}

class _TodayData {
  const _TodayData({
    required this.roadmap,
    this.streak,
    this.history = const <SpeakingSessionSummary>[],
    this.due = const <VocabularyReview>[],
  });

  final Roadmap roadmap;
  final HabitSnapshot? streak;
  final List<SpeakingSessionSummary> history;
  final List<VocabularyReview> due;
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(ToungularSpace.l),
    children: const <Widget>[
      SizedBox(
        height: 48,
        width: 220,
        child: ColoredBox(color: ToungularColor.sand),
      ),
      SizedBox(height: ToungularSpace.m),
      SizedBox(height: 180, child: ColoredBox(color: ToungularColor.sand)),
      SizedBox(height: ToungularSpace.m),
      SizedBox(height: 120, child: ColoredBox(color: ToungularColor.mist)),
    ],
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.title,
    required this.body,
    required this.action,
  });

  final String title;
  final String body;
  final Widget action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(ToungularSpace.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: ToungularSpace.xs),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: ToungularSpace.m),
          action,
        ],
      ),
    ),
  );
}

class _GreetingRow extends StatelessWidget {
  const _GreetingRow({required this.email, required this.streak});

  final String email;
  final int streak;

  static const _days = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final local = email.split('@').first;
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    final initial = local.isEmpty ? 'T' : local[0].toUpperCase();

    return Row(
      children: <Widget>[
        Semantics(
          button: true,
          label: 'Account settings',
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.push('/account'),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ToungularColor.lime,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                initial,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(width: ToungularSpace.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${_days[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                '$greeting, $local',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        const SizedBox(width: ToungularSpace.s),
        Semantics(
          label: '$streak day streak',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: ToungularColor.peach,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 16,
                  color: ToungularColor.coral,
                ),
                const SizedBox(width: 4),
                Text(
                  '$streak',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: ToungularColor.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.course, required this.lesson});

  final RoadmapCourse course;
  final RoadmapLesson lesson;

  @override
  Widget build(BuildContext context) {
    final step = lesson.position + 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ToungularSpace.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              "Today's session · ${lesson.durationMin} min",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: ToungularColor.leaf,
              ),
            ),
            const SizedBox(height: ToungularSpace.xs),
            Text(
              '${course.title} · ${lesson.title}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: ToungularSpace.xs),
            Text(
              '${course.level} · ${lesson.summary}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: ToungularSpace.m),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '$step of ${course.lessons.length} steps',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: ToungularColor.lime,
                    foregroundColor: ToungularColor.ink,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  onPressed: () => context.push('/lessons/${lesson.id}'),
                  child: const Text('Continue'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.week});

  final WeekActivity week;

  static const _letters = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _names = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final progress = week.target == 0
        ? 0.0
        : (week.sessions / week.target).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ToungularSpace.m),
        child: Row(
          children: <Widget>[
            Semantics(
              label: '${week.sessions} of ${week.target} sessions this week',
              excludeSemantics: true,
              child: SizedBox(
                width: 84,
                height: 84,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 9,
                      backgroundColor: ToungularColor.sand,
                      strokeCap: StrokeCap.round,
                    ),
                    Text(
                      '${week.sessions}/${week.target}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: ToungularSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'This week',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${week.sessions} of ${week.target} sessions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: ToungularSpace.s),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List<Widget>.generate(7, (index) {
                      final done = week.days[index];
                      return Semantics(
                        label:
                            '${_names[index]}: ${done ? 'session completed' : 'no session'}',
                        excludeSemantics: true,
                        child: Column(
                          children: <Widget>[
                            Text(
                              _letters[index],
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: done
                                    ? ToungularColor.leaf
                                    : ToungularColor.sand,
                                shape: BoxShape.circle,
                                border: index == week.todayIndex
                                    ? Border.all(
                                        color: ToungularColor.ink,
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeTiles extends StatelessWidget {
  const _PracticeTiles({required this.dueCount});

  final int dueCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _Tile(
            icon: Icons.style_outlined,
            color: ToungularColor.butter,
            title: 'Vocabulary',
            meta: dueCount > 0 ? '$dueCount due' : 'All caught up',
            onTap: () => context.push('/vocabulary'),
          ),
        ),
        const SizedBox(width: ToungularSpace.s),
        Expanded(
          child: _Tile(
            icon: Icons.mic_none_rounded,
            color: ToungularColor.mist,
            title: 'Speaking',
            meta: 'Say it out loud',
            onTap: () => context.push('/speaking'),
          ),
        ),
        const SizedBox(width: ToungularSpace.s),
        Expanded(
          child: _Tile(
            icon: Icons.graphic_eq_rounded,
            color: ToungularColor.sky,
            title: 'Shadowing',
            meta: 'Match the rhythm',
            onTap: () => context.push('/shadow'),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.color,
    required this.title,
    required this.meta,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(ToungularRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(ToungularSpace.s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: ToungularColor.ink),
              ),
              const SizedBox(height: ToungularSpace.s),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                meta,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.week});

  final WeekActivity week;

  static const _letters = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _names = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    var bestIndex = -1;
    for (var i = 0; i < 7; i++) {
      if (week.days[i]) {
        bestIndex = i;
        break;
      }
    }
    final footer = bestIndex == -1
        ? '${week.sessions} sessions · no session yet this week'
        : '${week.sessions} session${week.sessions == 1 ? '' : 's'} · best day: ${_names[bestIndex]}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ToungularSpace.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Your week', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: ToungularSpace.m),
            // No fixed height: the bars keep their 56/14 heights and the day
            // label adds its own space, so large text scales cannot clip it.
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List<Widget>.generate(7, (index) {
                final done = week.days[index];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        Container(
                          height: done ? 56 : 14,
                          decoration: BoxDecoration(
                            color: done
                                ? ToungularColor.leaf
                                : ToungularColor.sand,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _letters[index],
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: ToungularSpace.s),
            Text(footer, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
