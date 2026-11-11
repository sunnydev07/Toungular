import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/toungular_theme.dart';
import '../../shared/content/speaking_prompts.dart';
import '../../shared/models/learning_models.dart';
import '../auth/session_controller.dart';
import '../speaking/speaking_repository.dart';
import '../vocabulary/vocabulary_repository.dart';

class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  late Future<_PracticeData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_PracticeData> _load() async {
    final results = await Future.wait<Object?>(<Future<Object?>>[
      ref.read(speakingRepositoryProvider).history(),
      ref.read(vocabularyRepositoryProvider).loadDueItems(),
    ]);
    return _PracticeData(
      history:
          (results[0] as List<SpeakingSessionSummary>? ??
          const <SpeakingSessionSummary>[]),
      due:
          (results[1] as List<VocabularyReview>? ?? const <VocabularyReview>[]),
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _data = next);
    try {
      await next;
    } catch (_) {
      // The FutureBuilder shows the recoverable error state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final prompt = speakingPrompts[dailyPromptIndex(DateTime.now())];
    final proficiency = ref
        .watch(sessionControllerProvider)
        .session
        ?.profile
        .proficiency;

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_PracticeData>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(ToungularSpace.l),
                children: <Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(ToungularSpace.m),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Practice is unavailable',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: ToungularSpace.xs),
                          Text(
                            'Reconnect and try again.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: ToungularSpace.m),
                          OutlinedButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
            return _content(
              context,
              snapshot.data!,
              prompt.text,
              proficiency?.label,
            );
          },
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    _PracticeData data,
    String prompt,
    String? level,
  ) {
    final recent =
        data.history
            .where((session) => session.completedAt != null)
            .toList(growable: false)
          ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'PRACTICE',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: ToungularColor.leaf,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pick a way in.',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: ToungularSpace.xs),
                    Text(
                      'One session is enough to keep your English moving.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Speaking history',
                onPressed: () => context.push('/speaking/history'),
                icon: const Icon(Icons.history_outlined),
              ),
            ],
          ),
          const SizedBox(height: ToungularSpace.m),
          Container(
            padding: const EdgeInsets.all(ToungularSpace.m),
            decoration: BoxDecoration(
              color: ToungularColor.leaf,
              borderRadius: BorderRadius.circular(ToungularRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'PROMPT OF THE DAY',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ToungularColor.lime,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: ToungularSpace.xs),
                Text(
                  prompt,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: ToungularSpace.s),
                Row(
                  children: <Widget>[
                    if (level != null) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          level,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: ToungularSpace.xs),
                    ],
                    const Icon(
                      Icons.mic_none_rounded,
                      size: 16,
                      color: ToungularColor.lime,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Record, get a transcript, then try again with one tip.',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ToungularSpace.m),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: ToungularColor.lime,
                      foregroundColor: ToungularColor.ink,
                    ),
                    onPressed: () => context.push(
                      '/speaking?prompt=${Uri.encodeQueryComponent(prompt)}',
                    ),
                    child: const Text('Start speaking'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ToungularSpace.l),
          Row(
            children: <Widget>[
              Expanded(
                child: _GridTile(
                  icon: Icons.style_outlined,
                  color: ToungularColor.butter,
                  title: 'Vocabulary',
                  meta: data.due.isEmpty
                      ? 'All caught up'
                      : '${data.due.length} due now',
                  onTap: () => context.push('/vocabulary'),
                ),
              ),
              const SizedBox(width: ToungularSpace.s),
              Expanded(
                child: _GridTile(
                  icon: Icons.graphic_eq_rounded,
                  color: ToungularColor.sky,
                  title: 'Shadowing',
                  meta: 'Match native rhythm',
                  onTap: () => context.push('/shadow'),
                ),
              ),
            ],
          ),
          const SizedBox(height: ToungularSpace.s),
          Row(
            children: <Widget>[
              Expanded(
                child: _GridTile(
                  icon: Icons.auto_stories_outlined,
                  color: ToungularColor.lilac,
                  title: 'Reading',
                  meta: 'Comprehensible input',
                  onTap: () => context.push('/content'),
                ),
              ),
              const SizedBox(width: ToungularSpace.s),
              Expanded(
                child: _GridTile(
                  icon: Icons.school_outlined,
                  color: ToungularColor.peach,
                  title: 'IELTS',
                  meta: 'Timed speaking test',
                  onTap: () => context.push('/ielts'),
                ),
              ),
            ],
          ),
          const SizedBox(height: ToungularSpace.l),
          Text('Recent', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: ToungularSpace.xs),
          if (recent.isEmpty)
            Text(
              'Your finished speaking sessions will show here.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            for (final session in recent.take(3)) ...<Widget>[
              Card(
                margin: const EdgeInsets.only(bottom: ToungularSpace.xs),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ToungularRadius.card),
                  ),
                  onTap: () => context.push('/speaking/history'),
                  leading: const CircleAvatar(
                    backgroundColor: ToungularColor.mist,
                    child: Icon(
                      Icons.record_voice_over_outlined,
                      color: ToungularColor.leaf,
                    ),
                  ),
                  title: Text(
                    session.prompt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(_dateLabel(session.completedAt)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
            ],
          const SizedBox(height: ToungularSpace.m),
          Text('More practice', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: ToungularSpace.xs),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                _MoreRow(
                  icon: Icons.hearing_outlined,
                  title: 'Pronunciation lab',
                  subtitle: 'Minimal pairs and articulation',
                  onTap: () => context.push('/pronunciation'),
                ),
                const Divider(indent: 56),
                _MoreRow(
                  icon: Icons.spa_outlined,
                  title: 'Comfort path',
                  subtitle: 'Speak gently, one level at a time',
                  onTap: () => context.push('/exposure'),
                ),
                const Divider(indent: 56),
                _MoreRow(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Mastery profile',
                  subtitle: 'Your four-axis XP',
                  onTap: () => context.push('/mastery'),
                ),
                const Divider(indent: 56),
                _MoreRow(
                  icon: Icons.quiz_outlined,
                  title: 'Placement check',
                  subtitle: 'Set or repeat your starting point',
                  onTap: () => context.push('/placement'),
                ),
                const Divider(indent: 56),
                _MoreRow(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Coach',
                  subtitle: 'Role-play a conversation',
                  onTap: () => context.push('/coach'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime? completedAt) {
    final local = completedAt?.toLocal();
    if (local == null) return 'Speaking practice';
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} · $hour:$minute';
  }
}

class _PracticeData {
  const _PracticeData({required this.history, required this.due});

  final List<SpeakingSessionSummary> history;
  final List<VocabularyReview> due;
}

class _GridTile extends StatelessWidget {
  const _GridTile({
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

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: ToungularColor.mist,
        child: Icon(icon, color: ToungularColor.leaf, size: 20),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18),
    );
  }
}
