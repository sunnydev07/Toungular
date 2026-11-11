import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/toungular_theme.dart';
import '../../shared/models/learning_models.dart';
import 'exposure_repository.dart';

const _activities = <int, String>{
  1: 'Read or listen to any English for a few minutes. Notice three useful phrases: “small steps”, “notice how it feels”, and “build confidence”.',
  2: 'Whisper these lines three times: “I can speak slowly. I am learning every day. My voice matters.”',
  3: 'Record a short answer privately and play it back. No transcript or feedback is required.',
  4: 'Record a short answer and read the transcript-based feedback gently.',
  5: 'Shadow a graded model passage. Match rhythm, pause cadence, and speaking rate.',
  6: 'Hold a multi-turn conversation with your AI Coach on real-life scenarios.',
};

const _prompts = <int, String>{
  3: 'Record a short answer: what did you do today?',
  4: 'Record a short answer: describe one thing you noticed this week.',
};

class ExposureScreen extends ConsumerStatefulWidget {
  const ExposureScreen({super.key});

  @override
  ConsumerState<ExposureScreen> createState() => _ExposureScreenState();
}

class _ExposureScreenState extends ConsumerState<ExposureScreen> {
  late Future<ExposureSummary> _summary;
  int? _busyLevel;
  String? _error;

  @override
  void initState() {
    super.initState();
    _summary = ref.read(exposureRepositoryProvider).load();
  }

  Future<void> _refresh() async {
    setState(() => _summary = ref.read(exposureRepositoryProvider).load());
    try {
      await _summary;
    } catch (_) {
      // The FutureBuilder shows the retry state.
    }
  }

  Future<void> _complete(ExposureLevel level) async {
    setState(() {
      _busyLevel = level.level;
      _error = null;
    });
    try {
      final summary = await ref
          .read(exposureRepositoryProvider)
          .complete(level.level);
      if (!mounted) return;
      setState(() => _summary = Future<ExposureSummary>.value(summary));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Comfort level ${level.level} session recorded.'),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(
          () =>
              _error = 'This comfort session could not be recorded. Try again.',
        );
    } finally {
      if (mounted) setState(() => _busyLevel = null);
    }
  }

  Future<void> _openPractice(ExposureLevel level) async {
    if (level.level == 5) {
      await context.push('/shadow');
    } else if (level.level == 6) {
      await context.push('/coach');
    } else {
      await context.push(
        Uri(
          path: '/speaking',
          queryParameters: <String, String>{
            'type': 'exposure-${level.level}',
            'prompt':
                _prompts[level.level] ??
                'Record a short answer about your day.',
          },
        ).toString(),
      );
    }
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Comfort path')),
    body: SafeArea(
      child: FutureBuilder<ExposureSummary>(
        future: _summary,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(ToungularSpace.l),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Comfort practice could not load',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: ToungularSpace.s),
                    Text(
                      error is ApiException
                          ? error.message
                          : 'Reconnect and try again.',
                    ),
                    const SizedBox(height: ToungularSpace.m),
                    OutlinedButton(
                      onPressed: _refresh,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }
          final summary = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                ToungularSpace.l,
                ToungularSpace.s,
                ToungularSpace.l,
                ToungularSpace.xl,
              ),
              children: <Widget>[
                Text(
                  'Start where you feel comfortable.',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: ToungularSpace.s),
                Text(
                  'Complete ${summary.sessionsRequired} sessions at one level to unlock the next. '
                  'Level 7 remains unavailable until community sharing is enabled.',
                ),
                const SizedBox(height: ToungularSpace.l),
                for (final level in summary.levels) ...<Widget>[
                  _LevelCard(
                    level: level,
                    activity: _activities[level.level] ?? level.description,
                    busy: _busyLevel == level.level,
                    speakLabel: level.level == 5
                        ? 'Open shadow practice'
                        : level.level == 6
                        ? 'Open AI conversation'
                        : 'Open speaking practice',
                    onSpeak:
                        level.level >= 3 &&
                            level.unlocked &&
                            level.available &&
                            !level.complete
                        ? () => _openPractice(level)
                        : null,
                    onComplete:
                        level.unlocked && level.available && !level.complete
                        ? () => _complete(level)
                        : null,
                  ),
                  const SizedBox(height: ToungularSpace.s),
                ],
                if (_error != null) ...<Widget>[
                  const SizedBox(height: ToungularSpace.s),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.activity,
    required this.busy,
    required this.onSpeak,
    required this.onComplete,
    this.speakLabel = 'Open speaking practice',
  });

  final ExposureLevel level;
  final String activity;
  final bool busy;
  final VoidCallback? onSpeak;
  final VoidCallback? onComplete;
  final String speakLabel;

  @override
  Widget build(BuildContext context) {
    final status = level.complete
        ? 'Complete'
        : level.available
        ? level.unlocked
              ? '${level.sessionsCompleted} of ${level.sessionsRequired} sessions'
              : 'Locked until the previous level is complete'
        : 'Not available yet';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ToungularSpace.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: level.complete
                      ? ToungularColor.lime
                      : ToungularColor.mist,
                  child: Text('${level.level}'),
                ),
                const SizedBox(width: ToungularSpace.s),
                Expanded(
                  child: Text(
                    level.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (level.complete)
                  const Icon(Icons.check_circle, color: ToungularColor.leaf),
              ],
            ),
            const SizedBox(height: ToungularSpace.s),
            Text(level.description),
            const SizedBox(height: ToungularSpace.xs),
            Text(status, style: Theme.of(context).textTheme.labelLarge),
            if (level.unlocked &&
                level.available &&
                !level.complete) ...<Widget>[
              const SizedBox(height: ToungularSpace.s),
              Text(activity, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: ToungularSpace.s),
              if (onSpeak != null) ...<Widget>[
                FilledButton(
                  onPressed: busy ? null : onSpeak,
                  child: Text(speakLabel),
                ),
                const SizedBox(height: ToungularSpace.xs),
              ],
              OutlinedButton(
                onPressed: busy ? null : onComplete,
                child: Text(busy ? 'Saving…' : 'Mark session complete'),
              ),
            ] else if (!level.available && level.reason != null) ...<Widget>[
              const SizedBox(height: ToungularSpace.xs),
              Text(level.reason!),
            ],
          ],
        ),
      ),
    );
  }
}
