import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/toungular_theme.dart';
import '../../shared/models/learning_models.dart';
import '../auth/session_controller.dart';
import '../monetization/home_ad_banner.dart';
import 'roadmap_repository.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Future<Roadmap> _roadmap;

  @override
  void initState() {
    super.initState();
    _roadmap = ref.read(roadmapRepositoryProvider).load();
  }

  Future<void> _refresh() async {
    final next = ref.read(roadmapRepositoryProvider).load();
    setState(() => _roadmap = next);
    try {
      await next;
    } catch (_) {
      // The FutureBuilder shows the recoverable offline state below.
    }
  }

  Future<void> _signOut() async {
    await ref.read(sessionControllerProvider.notifier).signOut();
    if (mounted) context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final profile = session.session?.profile;
    final firstName = profile?.email.split('@').first ?? 'there';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Toungular'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Account settings',
            onPressed: () => context.go('/account'),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          IconButton(
            tooltip: 'Toungular Plus and referrals',
            onPressed: () => context.go('/plus'),
            icon: const Icon(Icons.workspace_premium_outlined),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(ToungularSpace.l, ToungularSpace.s, ToungularSpace.l, ToungularSpace.xl),
            children: <Widget>[
              Text('Good to see you, $firstName.', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: ToungularSpace.s),
              Text(
                'Your next step toward confident English starts here.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: ToungularSpace.l),
              _dailyGoalCard(context, profile?.dailyMinutes ?? 15),
              const ToungularHomeAdBanner(),
              const SizedBox(height: ToungularSpace.m),
              _skillOverview(context),
              const SizedBox(height: ToungularSpace.xl),
              Row(
                children: <Widget>[
                  Expanded(child: Text('Today’s path', style: Theme.of(context).textTheme.headlineSmall)),
                  TextButton(onPressed: () => context.go('/courses'), child: const Text('All courses')),
                ],
              ),
              const SizedBox(height: ToungularSpace.s),
              FutureBuilder<Roadmap>(
                future: _roadmap,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _InfoCard(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(ToungularSpace.l),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    final error = snapshot.error;
                    if (error is ApiException && error.isUnauthorized) {
                      return _InfoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Your session ended', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: ToungularSpace.s),
                            const Text('Sign in again to sync your learning path.'),
                            const SizedBox(height: ToungularSpace.m),
                            OutlinedButton(onPressed: _signOut, child: const Text('Sign in again')),
                          ],
                        ),
                      );
                    }
                    return _InfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Your path is unavailable', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: ToungularSpace.s),
                          const Text('Connect to Toungular to load your plan. Your account remains saved on this device.'),
                          const SizedBox(height: ToungularSpace.m),
                          OutlinedButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
                    );
                  }
                  return _roadmapContent(context, snapshot.data!);
                },
              ),
              const SizedBox(height: ToungularSpace.xl),
              Text('Practice your way', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: ToungularSpace.m),
              _quickLink(
                context,
                icon: Icons.hearing_outlined,
                title: 'Phoneme Lab (Minimal Pairs)',
                detail: 'Acoustic contrast & articulatory biomechanics',
                path: '/pronunciation',
                color: const Color(0xFFE0F7FA),
              ),
              const SizedBox(height: ToungularSpace.s),
              _quickLink(
                context,
                icon: Icons.workspace_premium_rounded,
                title: 'Mastery Profile (4-Axis XP)',
                detail: 'Self-Determination Theory competence & freeze tokens',
                path: '/mastery',
                color: const Color(0xFFFFF9C4),
              ),
              const SizedBox(height: ToungularSpace.s),
              _quickLink(
                context,
                icon: Icons.quiz_outlined,
                title: 'Vocabulary baseline',
                detail: 'Set a starting point for word recall',
                path: '/placement',
                color: const Color(0xFFE8F2FF),
              ),
              const SizedBox(height: ToungularSpace.s),
              _quickLink(
                context,
                icon: Icons.record_voice_over_rounded,
                title: 'Speaking',
                detail: 'Practice out loud',
                path: '/speaking',
                color: ToungularColor.mist,
              ),
              const SizedBox(height: ToungularSpace.s),
              _quickLink(
                context,
                icon: Icons.graphic_eq_rounded,
                title: 'Speech shadowing',
                detail: 'Match native rhythm, cadence & tempo',
                path: '/shadow',
                color: const Color(0xFFE0F2F1),
              ),
              const SizedBox(height: ToungularSpace.s),
              _quickLink(
                context,
                icon: Icons.auto_stories_outlined,
                title: 'Comprehensible input (i+1)',
                detail: 'Calibrated reading & output-forcing practice',
                path: '/content',
                color: const Color(0xFFF3E5F5),
              ),
              const SizedBox(height: ToungularSpace.s),
              _quickLink(
                context,
                icon: Icons.spa_outlined,
                title: 'Comfort path',
                detail: 'Start speaking gently, one level at a time',
                path: '/exposure',
                color: const Color(0xFFE8F5E9),
              ),
              const SizedBox(height: ToungularSpace.s),
              _quickLink(
                context,
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Coach and role-play',
                detail: 'Try a conversation',
                path: '/coach',
                color: const Color(0xFFFFF0E8),
              ),
              const SizedBox(height: ToungularSpace.s),
              _quickLink(
                context,
                icon: Icons.school_outlined,
                title: 'IELTS speaking',
                detail: 'Explore timed practice',
                path: '/ielts',
                color: const Color(0xFFF0EDFF),
              ),
              const SizedBox(height: ToungularSpace.s),
              _quickLink(
                context,
                icon: Icons.style_outlined,
                title: 'Vocabulary review',
                detail: 'Strengthen useful words with spaced recall',
                path: '/vocabulary',
                color: const Color(0xFFFFF2D9),
              ),
              const SizedBox(height: ToungularSpace.s),
              _quickLink(
                context,
                icon: Icons.insights_outlined,
                title: 'Progress',
                detail: 'See your learning journey',
                path: '/progress',
                color: const Color(0xFFEAF2FA),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dailyGoalCard(BuildContext context, int minutes) {
    return Card(
      color: ToungularColor.ink,
      child: Padding(
        padding: const EdgeInsets.all(ToungularSpace.l),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Your daily goal', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                  const SizedBox(height: ToungularSpace.xs),
                  Text(
                    '$minutes minutes of focused practice',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: ToungularSpace.s),
                  const Text('A small, consistent step makes progress easier to keep.'),
                  const SizedBox(height: ToungularSpace.xs),
                  const Text('Your streak starts with your next practice.'),
                ],
              ),
            ),
            const SizedBox(width: ToungularSpace.m),
            const Icon(Icons.auto_awesome_rounded, color: ToungularColor.lime, size: 34),
          ],
        ),
      ),
    );
  }

  Widget _skillOverview(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.push('/mastery'),
            child: _InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.forum_outlined, color: ToungularColor.leaf),
                  const SizedBox(height: ToungularSpace.s),
                  Text('Fluency XP', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: ToungularSpace.xs),
                  const Text('View Mastery Profile'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: ToungularSpace.s),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.push('/mastery'),
            child: _InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.menu_book_outlined, color: ToungularColor.coral),
                  const SizedBox(height: ToungularSpace.s),
                  Text('Lexical XP', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: ToungularSpace.xs),
                  const Text('4-Axis Skill Radar'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _roadmapContent(BuildContext context, Roadmap roadmap) {
    final lesson = roadmap.nextLesson;
    final cachedNote = roadmap.source == RoadmapSource.cached
        ? Padding(
            padding: const EdgeInsets.only(bottom: ToungularSpace.s),
            child: Text(
              'Showing your saved learning path. Pull down to sync when you are online.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        : const SizedBox.shrink();

    if (lesson == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          cachedNote,
          _InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('You’re all caught up', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: ToungularSpace.s),
                const Text('More lessons will be added to your English path.'),
                const SizedBox(height: ToungularSpace.m),
                Text(roadmap.completedLessonCount.toString() + ' lessons completed'),
              ],
            ),
          ),
        ],
      );
    }

    final course = roadmap.courses.firstWhere(
      (item) => item.lessons.any((candidate) => candidate.id == lesson.id),
      orElse: () => roadmap.courses.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        cachedNote,
        _InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.wb_sunny_outlined, color: ToungularColor.coral),
                  const SizedBox(width: ToungularSpace.s),
                  Expanded(child: Text(course.title, style: Theme.of(context).textTheme.titleMedium)),
                  Text(lesson.durationMin.toString() + ' min', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: ToungularSpace.m),
              Text(lesson.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: ToungularSpace.s),
              Text(lesson.summary, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: ToungularSpace.l),
              FilledButton.icon(
                onPressed: () => context.go('/lessons/${lesson.id}'),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Continue learning'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickLink(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String detail,
    required String path,
    required Color color,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: ToungularSpace.m, vertical: ToungularSpace.xs),
        leading: CircleAvatar(backgroundColor: color, child: Icon(icon, color: ToungularColor.ink)),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(detail),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: () => context.go(path),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(ToungularSpace.m),
          child: child,
        ),
      );
}
