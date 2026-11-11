import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/toungular_theme.dart';
import '../../shared/models/learning_models.dart';
import '../home/roadmap_repository.dart';
import '../monetization/monetization_repository.dart';
import '../monetization/toungular_ads_service.dart';
import '../../core/config/app_environment.dart';
import '../../core/state/voice_activity_controller.dart';

class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  late Future<Roadmap> _roadmap;
  bool _bonusUnlocked = false;
  bool _rewardLoading = false;
  String? _rewardMessage;

  @override
  void initState() {
    super.initState();
    _roadmap = ref.read(roadmapRepositoryProvider).load();
  }

  Future<void> _refresh() async {
    final request = ref.read(roadmapRepositoryProvider).load();
    setState(() => _roadmap = request);
    try {
      await request;
    } catch (_) {
      // Keep the saved path visible if the network is still unavailable.
    }
  }

  Future<void> _unlockBonus() async {
    setState(() {
      _rewardLoading = true;
      _rewardMessage = null;
    });
    try {
      final entitlement = await ref.read(entitlementSnapshotProvider.future);
      final earned = await ToungularAdsService.instance.showRewardedBonus(
        isPremium: entitlement.premium,
        voiceActive: ref.read(voiceActivityProvider),
      );
      if (mounted)
        setState(() {
          _bonusUnlocked = earned;
          _rewardMessage = earned
              ? null
              : 'A rewarded ad is not available right now.';
        });
    } catch (_) {
      if (mounted)
        setState(
          () => _rewardMessage = 'A rewarded ad is not available right now.',
        );
    } finally {
      if (mounted) setState(() => _rewardLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Learn')),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<Roadmap>(
          future: _roadmap,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final error = snapshot.error;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(ToungularSpace.l),
                children: <Widget>[
                  Text(
                    'Your courses could not load',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: ToungularSpace.s),
                  Text(
                    error is ApiException
                        ? error.message
                        : 'Try again when you are connected.',
                  ),
                  const SizedBox(height: ToungularSpace.m),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              );
            }
            final roadmap = snapshot.data!;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                ToungularSpace.l,
                ToungularSpace.s,
                ToungularSpace.l,
                ToungularSpace.xl,
              ),
              children: <Widget>[
                Text(
                  'Build English you can use.',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: ToungularSpace.s),
                const Text(
                  'Short lessons help you express ideas clearly, one conversation at a time.',
                ),
                if (roadmap.source == RoadmapSource.cached) ...<Widget>[
                  const SizedBox(height: ToungularSpace.m),
                  const _OfflineNotice(),
                ],
                const SizedBox(height: ToungularSpace.l),
                for (final course in roadmap.courses) ...<Widget>[
                  _CourseCard(course: course),
                  const SizedBox(height: ToungularSpace.m),
                ],
                if (AppEnvironment.adsEnabled) ...<Widget>[
                  Card(
                    color: ToungularColor.mist,
                    child: Padding(
                      padding: const EdgeInsets.all(ToungularSpace.m),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Unlock a bonus prompt',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: ToungularSpace.xs),
                          const Text(
                            'An optional rewarded ad opens one extra original speaking practice prompt.',
                          ),
                          if (_bonusUnlocked) ...<Widget>[
                            const SizedBox(height: ToungularSpace.s),
                            const Text(
                              'Describe a skill you practiced and how you noticed your progress.',
                            ),
                            const SizedBox(height: ToungularSpace.s),
                            OutlinedButton(
                              onPressed: () => context.push(
                                '/speaking?prompt=Describe%20a%20skill%20you%20practiced%20and%20how%20you%20noticed%20your%20progress.',
                              ),
                              child: const Text('Start bonus practice'),
                            ),
                          ] else ...<Widget>[
                            const SizedBox(height: ToungularSpace.s),
                            OutlinedButton(
                              onPressed: _rewardLoading ? null : _unlockBonus,
                              child: Text(
                                _rewardLoading
                                    ? 'Loading ad…'
                                    : 'Watch rewarded ad',
                              ),
                            ),
                          ],
                          if (_rewardMessage != null) ...<Widget>[
                            const SizedBox(height: ToungularSpace.xs),
                            Text(_rewardMessage!),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: ToungularSpace.m),
                ],
                OutlinedButton.icon(
                  onPressed: () => context.push('/vocabulary'),
                  icon: const Icon(Icons.style_outlined),
                  label: const Text('Review vocabulary'),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});

  final RoadmapCourse course;

  @override
  Widget build(BuildContext context) {
    final completed = course.lessons
        .where((lesson) => lesson.isComplete)
        .length;
    final next = course.nextLesson;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ToungularSpace.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    course.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  course.level,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: ToungularSpace.s),
            Text(course.description),
            const SizedBox(height: ToungularSpace.m),
            LinearProgressIndicator(
              value: course.lessons.isEmpty
                  ? 0
                  : completed / course.lessons.length,
            ),
            const SizedBox(height: ToungularSpace.xs),
            Text('$completed of ${course.lessons.length} lessons complete'),
            const SizedBox(height: ToungularSpace.s),
            for (final lesson in course.lessons)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  lesson.isComplete
                      ? Icons.check_circle
                      : Icons.play_circle_outline,
                  color: ToungularColor.leaf,
                ),
                title: Text(lesson.title),
                subtitle: Text('${lesson.durationMin} min · ${lesson.summary}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/lessons/${lesson.id}'),
              ),
            if (next != null)
              FilledButton.icon(
                onPressed: () => context.push('/lessons/${next.id}'),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue course'),
              ),
          ],
        ),
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) => const Card(
    color: ToungularColor.mist,
    child: Padding(
      padding: EdgeInsets.all(ToungularSpace.m),
      child: Row(
        children: <Widget>[
          Icon(Icons.cloud_off_outlined),
          SizedBox(width: ToungularSpace.s),
          Expanded(
            child: Text(
              'Saved lessons remain available. Progress will sync when you reconnect.',
            ),
          ),
        ],
      ),
    ),
  );
}
