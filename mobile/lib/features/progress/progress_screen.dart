import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/toungular_theme.dart';
import 'reminder_notifications.dart';
import 'progress_repository.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});
  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  TimeOfDay _reminderTime = const TimeOfDay(hour: 19, minute: 0);
  final Set<int> _days = <int>{1, 2, 3, 4, 5};
  bool _initialized = false;
  bool _savingReminder = false;
  String? _message;
  String? _error;

  Future<void> _refresh() async {
    ref.invalidate(progressSummaryProvider);
    ref.invalidate(streakProvider);
    try {
      await ref.read(progressSummaryProvider.future);
    } catch (_) {
      // The error state below reports the recoverable failure.
    }
  }

  Future<void> _saveReminder() async {
    setState(() {
      _savingReminder = true;
      _error = null;
      _message = null;
    });
    try {
      final time = _days.isEmpty
          ? null
          : '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}';
      await ref
          .read(progressRepositoryProvider)
          .updateReminder(time: time, days: _days.toList()..sort());
      final delivered = await ReminderNotifications.instance.configure(
        time: time,
        days: _days.toList(),
      );
      if (mounted) {
        setState(() {
          _message = _days.isEmpty
              ? 'Reminder schedule cleared.'
              : delivered
              ? 'Your reminder is saved and scheduled on this device.'
              : 'Your reminder preference is saved to your profile, but Android notifications are disabled for Toungular.';
        });
        ref.invalidate(progressSummaryProvider);
        ref.invalidate(streakProvider);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Your reminder preference could not be saved.');
      }
    } finally {
      if (mounted) setState(() => _savingReminder = false);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked != null && mounted) setState(() => _reminderTime = picked);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your progress')),
    body: ref
        .watch(progressSummaryProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(ToungularSpace.l),
              child: Text(
                error is ApiException
                    ? error.message
                    : 'Progress could not load.',
              ),
            ),
          ),
          data: (progress) {
            final streakValue = ref.watch(streakProvider);
            final streak = streakValue.value;
            if (streak == null) {
              return streakValue.hasError
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(ToungularSpace.l),
                        child: Text('Progress could not load.'),
                      ),
                    )
                  : const Center(child: CircularProgressIndicator());
            }
            if (!_initialized) {
              _initialized = true;
              _days
                ..clear()
                ..addAll(streak.reminderDays);
              final savedTime = streak.reminderTime?.split(':');
              if (savedTime != null && savedTime.length == 2) {
                _reminderTime = TimeOfDay(
                  hour: int.tryParse(savedTime[0]) ?? 19,
                  minute: int.tryParse(savedTime[1]) ?? 0,
                );
              }
            }
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
                    'Progress you can build on.',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: ToungularSpace.s),
                  Text(progress.note),
                  const SizedBox(height: ToungularSpace.l),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _MetricCard(
                          title: 'Fluency practice',
                          value: progress.speakingSessionsCompleted.toString(),
                          caption: 'completed speaking sessions',
                          icon: Icons.forum_outlined,
                        ),
                      ),
                      const SizedBox(width: ToungularSpace.s),
                      Expanded(
                        child: _MetricCard(
                          title: 'Vocabulary',
                          value: progress.vocabularyRecallRepetitions
                              .toString(),
                          caption: 'successful review repetitions',
                          icon: Icons.menu_book_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ToungularSpace.s),
                  _MetricCard(
                    title: 'Lessons',
                    value: progress.lessonsCompleted.toString(),
                    caption: 'completed lessons',
                    icon: Icons.check_circle_outline,
                  ),
                  const SizedBox(height: ToungularSpace.s),
                  Card(
                    color: ToungularColor.mist,
                    child: Padding(
                      padding: const EdgeInsets.all(ToungularSpace.m),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Vocabulary baseline',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: ToungularSpace.xs),
                          Text(
                            progress.vocabularyBaselineScore == null
                                ? 'Not set yet'
                                : 'First check: ${progress.vocabularyBaselineScore} of 20 · Latest: ${progress.vocabularyLatestScore} of 20',
                          ),
                          if (progress.vocabularyScoreChange != null)
                            Text(
                              '${progress.vocabularyScoreChange! >= 0 ? '+' : ''}${progress.vocabularyScoreChange} items from your first check.',
                            ),
                          const SizedBox(height: ToungularSpace.s),
                          OutlinedButton.icon(
                            onPressed: () => context.push('/placement'),
                            icon: const Icon(Icons.quiz_outlined),
                            label: Text(
                              progress.vocabularyBaselineScore == null
                                  ? 'Set a starting point'
                                  : 'Repeat vocabulary check',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: ToungularSpace.s),
                  Card(
                    color: ToungularColor.mist,
                    child: Padding(
                      padding: const EdgeInsets.all(ToungularSpace.m),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Fluency baseline',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: ToungularSpace.xs),
                          Text(
                            progress.fluencyBaselineWpm == null
                                ? '${progress.fluencyBaselineSessions} of 2 fixed speaking prompts completed.'
                                : 'Baseline pace estimate: about ${progress.fluencyBaselineWpm} words per minute.',
                          ),
                          if (progress.fluencyScoreChange != null)
                            Text(
                              '${progress.fluencyScoreChange! >= 0 ? '+' : ''}${progress.fluencyScoreChange} words per minute from your baseline.',
                            ),
                          const SizedBox(height: ToungularSpace.s),
                          OutlinedButton(
                            onPressed: () => context.push(
                              Uri(
                                path: '/speaking',
                                queryParameters: <String, String>{
                                  'type': 'baseline',
                                  'prompt': 'Describe a routine that helps you learn something new. Give one specific example.',
                                },
                              ).toString(),
                            ),
                            child: const Text('Baseline prompt 1'),
                          ),
                          OutlinedButton(
                            onPressed: () => context.push(
                              Uri(
                                path: '/speaking',
                                queryParameters: <String, String>{
                                  'type': 'baseline',
                                  'prompt': 'Talk about a time you explained an idea to another person.',
                                },
                              ).toString(),
                            ),
                            child: const Text('Baseline prompt 2'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: ToungularSpace.s),
                  Card(
                    color: ToungularColor.mist,
                    child: Padding(
                      padding: const EdgeInsets.all(ToungularSpace.m),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Pace trend',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: ToungularSpace.xs),
                          if (progress.fluencyTrend.isEmpty)
                            const Text(
                              'Complete speaking sessions to build a words-per-minute trend.',
                            )
                          else ...<Widget>[
                            Text(
                              '${progress.fluencyTrend.length} recent session${progress.fluencyTrend.length == 1 ? '' : 's'} · last ${progress.fluencyTrend.last} words per minute',
                            ),
                            const SizedBox(height: ToungularSpace.s),
                            _TrendBars(points: progress.fluencyTrend),
                            if (progress.fluencyWpmVariance !=
                                null) ...<Widget>[
                              const SizedBox(height: ToungularSpace.xs),
                              Text(
                                'Session-to-session variation: ${progress.fluencyWpmVariance} words per minute.',
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: ToungularSpace.m),
                  Card(
                    color: ToungularColor.ink,
                    child: Padding(
                      padding: const EdgeInsets.all(ToungularSpace.l),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.local_fire_department_outlined,
                            color: ToungularColor.lime,
                            size: 34,
                          ),
                          const SizedBox(width: ToungularSpace.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '${streak.currentDays} day streak',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: ToungularSpace.xs),
                                Text(
                                  'Longest: ${streak.longestDays} days',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: ToungularSpace.xl),
                  Text(
                    'Choose a reminder',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: ToungularSpace.xs),
                  const Text('Pick the days and time that suit your routine.'),
                  const SizedBox(height: ToungularSpace.s),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(ToungularSpace.m),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            spacing: ToungularSpace.xs,
                            children: List<Widget>.generate(
                              7,
                              (day) => FilterChip(
                                label: Text(
                                  const <String>[
                                    'S',
                                    'M',
                                    'T',
                                    'W',
                                    'T',
                                    'F',
                                    'S',
                                  ][day],
                                ),
                                selected: _days.contains(day),
                                onSelected: (selected) => setState(
                                  () => selected
                                      ? _days.add(day)
                                      : _days.remove(day),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: ToungularSpace.s),
                          OutlinedButton.icon(
                            onPressed: _pickTime,
                            icon: const Icon(Icons.schedule),
                            label: Text(_reminderTime.format(context)),
                          ),
                          const SizedBox(height: ToungularSpace.s),
                          FilledButton(
                            onPressed: _savingReminder ? null : _saveReminder,
                            child: Text(
                              _savingReminder
                                  ? 'Saving…'
                                  : _days.isEmpty
                                  ? 'Clear reminder'
                                  : 'Save reminder',
                            ),
                          ),
                          const SizedBox(height: ToungularSpace.xs),
                          const Text(
                            'Toungular asks Android for notification permission when you save a reminder.',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_message != null) ...<Widget>[
                    const SizedBox(height: ToungularSpace.s),
                    Text(
                      _message!,
                      style: const TextStyle(color: ToungularColor.leaf),
                    ),
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
                  const SizedBox(height: ToungularSpace.m),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/speaking/history'),
                    icon: const Icon(Icons.history),
                    label: const Text('Speaking history'),
                  ),
                ],
              ),
            );
          },
        ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
  });
  final String title;
  final String value;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(ToungularSpace.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: ToungularColor.leaf),
          const SizedBox(height: ToungularSpace.s),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: ToungularSpace.xs),
          Text(value, style: Theme.of(context).textTheme.displaySmall),
          Text(caption, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    ),
  );
}

class _TrendBars extends StatelessWidget {
  const _TrendBars({required this.points});

  final List<int> points;

  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );
    return SizedBox(
      height: 76,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points
            .map(
              (point) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        '$point',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        height: maxValue == 0
                            ? 8
                            : (point / maxValue * 46).clamp(8, 46).toDouble(),
                        decoration: BoxDecoration(
                          color: ToungularColor.leaf,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
