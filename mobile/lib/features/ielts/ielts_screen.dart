import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/toungular_theme.dart';
import '../../shared/models/learning_models.dart';
import 'ielts_repository.dart';

class IeltsScreen extends ConsumerStatefulWidget {
  const IeltsScreen({super.key});
  @override
  ConsumerState<IeltsScreen> createState() => _IeltsScreenState();
}

class _IeltsScreenState extends ConsumerState<IeltsScreen> {
  late Future<(List<IeltsMock>, List<IeltsAttemptRecord>)> _listData;
  Timer? _preparationTimer;
  IeltsMock? _activeMock;
  IeltsAttemptReference? _attempt;
  String? _summary;
  IeltsBandRubric? _completedRubric;
  String? _error;
  int _sectionIndex = 0;
  int? _preparationRemaining;
  Set<String> _completedSectionIds = <String>{};
  bool _preparationStarted = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _listData = _loadListData();
  }

  Future<(List<IeltsMock>, List<IeltsAttemptRecord>)> _loadListData() async {
    final repository = ref.read(ieltsRepositoryProvider);
    final results = await Future.wait<Object>(<Future<Object>>[
      repository.loadMocks(),
      repository.history(),
    ]);
    return (
      results[0] as List<IeltsMock>,
      results[1] as List<IeltsAttemptRecord>,
    );
  }

  IeltsMock? _findMock(List<IeltsMock> mocks, String mockId) {
    for (final mock in mocks) {
      if (mock.id == mockId) return mock;
    }
    return null;
  }

  @override
  void dispose() {
    _preparationTimer?.cancel();
    super.dispose();
  }

  Future<void> _start(IeltsMock mock) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final attempt = await ref
          .read(ieltsRepositoryProvider)
          .startAttempt(mock.id);
      if (mounted) {
        setState(() {
          _activeMock = mock;
          _attempt = attempt;
          _sectionIndex = 0;
          _completedSectionIds = <String>{};
          _preparationStarted = false;
          _preparationRemaining = null;
          _summary = null;
          _completedRubric = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'This timed practice could not start.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _resume(IeltsMock mock, IeltsAttemptRecord record) {
    final completed = record.answeredSectionIds;
    final nextIndex = mock.sections.indexWhere(
      (section) => !completed.contains(section.id),
    );
    setState(() {
      _activeMock = mock;
      _attempt = IeltsAttemptReference(
        id: record.id,
        mockId: record.mockId,
        status: record.status,
      );
      _completedSectionIds = completed;
      _sectionIndex = nextIndex < 0 ? mock.sections.length - 1 : nextIndex;
      _preparationStarted = false;
      _preparationRemaining = null;
      _summary = null;
      _completedRubric = null;
      _error = null;
    });
    if (nextIndex < 0) _finishAttempt();
  }

  void _startPreparation(IeltsSection section) {
    _preparationTimer?.cancel();
    setState(() {
      _preparationStarted = true;
      _preparationRemaining = section.preparationSeconds;
    });
    if (section.preparationSeconds == 0) return;
    _preparationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = (_preparationRemaining ?? 0) - 1;
      setState(() => _preparationRemaining = remaining < 0 ? 0 : remaining);
      if (remaining <= 0) timer.cancel();
    });
  }

  Future<void> _answerSection(IeltsSection section) async {
    final attempt = _attempt;
    if (attempt == null) return;
    _preparationTimer?.cancel();
    final result = await context.push<bool>(
      '/ielts/response',
      extra: IeltsResponseArgs(attemptId: attempt.id, section: section),
    );
    if (result != true || !mounted) return;
    _completedSectionIds.add(section.id);
    final sections = _activeMock?.sections ?? const <IeltsSection>[];
    var nextIndex = -1;
    for (var index = _sectionIndex + 1; index < sections.length; index++) {
      if (!_completedSectionIds.contains(sections[index].id)) {
        nextIndex = index;
        break;
      }
    }
    if (nextIndex >= 0) {
      setState(() {
        _sectionIndex = nextIndex;
        _preparationRemaining = null;
        _preparationStarted = false;
      });
      return;
    }
    await _finishAttempt();
  }

  Future<void> _finishAttempt() async {
    final attempt = _attempt;
    if (attempt == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final record = await ref
          .read(ieltsRepositoryProvider)
          .finishAttempt(attempt.id);
      if (mounted) {
        setState(() {
          _summary = record.feedback;
          _completedRubric = record.rubric;
          _listData = _loadListData();
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Your practice attempt could not be saved.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('IELTS-style practice')),
    body: _activeMock == null ? _mockList() : _activeAttempt(),
  );

  Widget
  _mockList() => FutureBuilder<(List<IeltsMock>, List<IeltsAttemptRecord>)>(
    future: _listData,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        final error = snapshot.error;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(ToungularSpace.l),
            child: Text(
              error is ApiException
                  ? error.message
                  : 'Practice sets could not load.',
            ),
          ),
        );
      }
      final mocks = snapshot.data!.$1;
      final attempts = snapshot.data!.$2;
      return RefreshIndicator(
        onRefresh: () async => setState(() => _listData = _loadListData()),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(ToungularSpace.l),
          children: <Widget>[
            Text(
              'Practice the structure.',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: ToungularSpace.s),
            const Text(
              'These are original IELTS-style speaking prompts. Toungular provides no official test affiliation or band score.',
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: ToungularSpace.s),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (attempts.isNotEmpty) ...<Widget>[
              const SizedBox(height: ToungularSpace.m),
              Text(
                'Your practice history',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: ToungularSpace.s),
              for (final attempt in attempts)
                _AttemptCard(
                  attempt: attempt,
                  mock: _findMock(mocks, attempt.mockId),
                  busy: _busy,
                  onResume: (mock) => _resume(mock, attempt),
                ),
            ],
            const SizedBox(height: ToungularSpace.l),
            for (final mock in mocks)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(ToungularSpace.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        mock.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: ToungularSpace.xs),
                      Text(mock.description),
                      const SizedBox(height: ToungularSpace.s),
                      for (final section in mock.sections)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.timer_outlined),
                          title: Text(section.title),
                          subtitle: Text(
                            '${section.preparationSeconds}s preparation · up to ${section.responseSeconds}s response',
                          ),
                        ),
                      const SizedBox(height: ToungularSpace.s),
                      FilledButton(
                        onPressed: _busy ? null : () => _start(mock),
                        child: Text(_busy ? 'Starting…' : 'Start practice set'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _activeAttempt() {
    final mock = _activeMock!;
    final section = mock.sections[_sectionIndex];
    if (_summary != null) {
      return ListView(
        padding: const EdgeInsets.all(ToungularSpace.l),
        children: <Widget>[
          const Icon(
            Icons.check_circle_outline,
            color: ToungularColor.leaf,
            size: 54,
          ),
          const SizedBox(height: ToungularSpace.m),
          Text(
            'Practice complete',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ToungularSpace.s),
          Text(_summary!, textAlign: TextAlign.center),
          const SizedBox(height: ToungularSpace.m),
          if (_completedRubric != null) ...<Widget>[
            _IeltsBandScorecard(rubric: _completedRubric!),
            const SizedBox(height: ToungularSpace.m),
          ] else ...<Widget>[
            const Text(
              'This is not an official IELTS result.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ToungularSpace.m),
          ],
          FilledButton(
            onPressed: () => setState(() {
              _activeMock = null;
              _attempt = null;
              _summary = null;
              _completedRubric = null;
            }),
            child: const Text('Return to practice sets'),
          ),
        ],
      );
    }
    final prepDone = _preparationStarted && (_preparationRemaining ?? 0) == 0;
    return ListView(
      padding: const EdgeInsets.all(ToungularSpace.l),
      children: <Widget>[
        Text(mock.title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: ToungularSpace.s),
        Text(section.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: ToungularSpace.s),
        LinearProgressIndicator(
          value: (_sectionIndex + 1) / mock.sections.length,
        ),
        const SizedBox(height: ToungularSpace.l),
        Card(
          color: ToungularColor.mist,
          child: Padding(
            padding: const EdgeInsets.all(ToungularSpace.l),
            child: Text(
              section.prompt,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        const SizedBox(height: ToungularSpace.l),
        if (!_preparationStarted)
          FilledButton.icon(
            onPressed: () => _startPreparation(section),
            icon: const Icon(Icons.timer),
            label: Text('Start ${section.preparationSeconds}s preparation'),
          )
        else if (!prepDone)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(ToungularSpace.l),
              child: Text(
                'Prepare your main idea and one example. ${_preparationRemaining ?? 0} seconds left.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          )
        else
          FilledButton.icon(
            onPressed: _busy ? null : () => _answerSection(section),
            icon: const Icon(Icons.mic),
            label: Text('Start ${section.responseSeconds}s response'),
          ),
        if (_completedSectionIds.contains(section.id))
          const Padding(
            padding: EdgeInsets.only(top: ToungularSpace.s),
            child: Text('This section was already saved.'),
          ),
        const SizedBox(height: ToungularSpace.s),
        OutlinedButton(
          onPressed: _busy ? null : _finishAttempt,
          child: Text(_busy ? 'Saving…' : 'Finish practice set'),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: ToungularSpace.s),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _AttemptCard extends StatefulWidget {
  const _AttemptCard({
    required this.attempt,
    required this.mock,
    required this.busy,
    required this.onResume,
  });

  final IeltsAttemptRecord attempt;
  final IeltsMock? mock;
  final bool busy;
  final ValueChanged<IeltsMock> onResume;

  @override
  State<_AttemptCard> createState() => _AttemptCardState();
}

class _AttemptCardState extends State<_AttemptCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final attempt = widget.attempt;
    final mock = widget.mock;
    final date = attempt.startedAt?.toLocal();
    final dateLabel = date == null
        ? 'Date unavailable'
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
                    mock?.title ?? 'Speaking practice',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (attempt.rubric != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ToungularColor.lime,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Band ${attempt.rubric!.overallBandEstimate.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: ToungularColor.ink,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: ToungularSpace.xs),
            Text(
              '$dateLabel · ${attempt.responses.length} section${attempt.responses.length == 1 ? '' : 's'} saved · ${attempt.isInProgress ? 'In progress' : 'Completed'}',
            ),
            if (attempt.feedback != null) ...<Widget>[
              const SizedBox(height: ToungularSpace.xs),
              Text(attempt.feedback!),
            ],
            if (attempt.rubric != null) ...<Widget>[
              const SizedBox(height: ToungularSpace.s),
              TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                label: Text(_expanded ? 'Hide band scorecard' : 'View band scorecard'),
              ),
              if (_expanded) ...<Widget>[
                const SizedBox(height: ToungularSpace.s),
                _IeltsBandScorecard(rubric: attempt.rubric!),
              ],
            ],
            if (attempt.isInProgress && mock != null) ...<Widget>[
              const SizedBox(height: ToungularSpace.s),
              OutlinedButton.icon(
                onPressed: widget.busy ? null : () => widget.onResume(mock),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume practice'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IeltsBandScorecard extends StatelessWidget {
  const _IeltsBandScorecard({required this.rubric});

  final IeltsBandRubric rubric;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(ToungularSpace.m),
      decoration: BoxDecoration(
        color: ToungularColor.ink,
        borderRadius: BorderRadius.circular(ToungularRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Estimated Band Score',
                style: textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ToungularColor.lime,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Band ${rubric.overallBandEstimate.toStringAsFixed(1)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: ToungularColor.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ToungularSpace.xs),
          Text(
            rubric.disclaimer,
            style: textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: ToungularSpace.m),
          const Divider(color: Colors.white24),
          const SizedBox(height: ToungularSpace.s),
          _criterionRow(context, rubric.fluencyAndCoherence),
          const SizedBox(height: ToungularSpace.s),
          _criterionRow(context, rubric.lexicalResource),
          const SizedBox(height: ToungularSpace.s),
          _criterionRow(context, rubric.grammaticalRange),
          const SizedBox(height: ToungularSpace.s),
          _criterionRow(context, rubric.pronunciation),
          if (rubric.upgradedPhrases.isNotEmpty) ...<Widget>[
            const SizedBox(height: ToungularSpace.m),
            const Divider(color: Colors.white24),
            const SizedBox(height: ToungularSpace.s),
            Text(
              'Phrase Upgrades',
              style: textTheme.titleSmall?.copyWith(
                color: ToungularColor.lime,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: ToungularSpace.xs),
            for (final phrase in rubric.upgradedPhrases) ...<Widget>[
              Container(
                margin: const EdgeInsets.only(top: ToungularSpace.xs),
                padding: const EdgeInsets.all(ToungularSpace.s),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '“${phrase.original}”',
                            style: const TextStyle(
                              color: Colors.white70,
                              decoration: TextDecoration.lineThrough,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: ToungularColor.lime,
                        ),
                        const SizedBox(width: ToungularSpace.xs),
                        Expanded(
                          child: Text(
                            '“${phrase.upgraded}”',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phrase.reason,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _criterionRow(BuildContext context, IeltsCriterionScore criterion) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Text(
                criterion.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                criterion.score.toStringAsFixed(1),
                style: const TextStyle(
                  color: ToungularColor.lime,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          criterion.notes,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}
