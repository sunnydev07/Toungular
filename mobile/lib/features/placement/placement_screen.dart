import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/toungular_theme.dart';
import '../../shared/models/learning_models.dart';
import 'placement_repository.dart';

class PlacementScreen extends ConsumerStatefulWidget {
  const PlacementScreen({super.key});
  @override
  ConsumerState<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends ConsumerState<PlacementScreen> {
  late Future<List<PlacementQuestion>> _questions;
  final Map<String, String> _answers = <String, String>{};
  int _index = 0;
  bool _busy = false;
  PlacementResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _questions = ref
        .read(placementRepositoryProvider)
        .loadVocabularyQuestions();
  }

  Future<void> _choose(PlacementQuestion question, String answer) async {
    _answers[question.id] = answer;
    if (_index + 1 < 20) {
      setState(() => _index++);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(placementRepositoryProvider)
          .submitVocabularyAnswers(_answers);
      if (mounted) setState(() => _result = result);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Your vocabulary check could not be saved. Try again.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Vocabulary baseline')),
    body: FutureBuilder<List<PlacementQuestion>>(
      future: _questions,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) {
          final error = snapshot.error;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(ToungularSpace.l),
              child: Text(
                error is ApiException
                    ? error.message
                    : 'The placement check could not load.',
              ),
            ),
          );
        }
        final questions = snapshot.data!;
        if (_result != null) return _resultContent(_result!);
        final question = questions[_index];
        return ListView(
          padding: const EdgeInsets.all(ToungularSpace.l),
          children: <Widget>[
            Text(
              'Build a starting point.',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: ToungularSpace.s),
            const Text(
              'Choose the word that best matches each meaning. Use your first instinct; you can repeat the same check later to compare recall.',
            ),
            const SizedBox(height: ToungularSpace.l),
            LinearProgressIndicator(value: (_index + 1) / questions.length),
            const SizedBox(height: ToungularSpace.s),
            Text(
              'Question ${_index + 1} of ${questions.length}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: ToungularSpace.m),
            Card(
              color: ToungularColor.mist,
              child: Padding(
                padding: const EdgeInsets.all(ToungularSpace.l),
                child: Text(
                  question.prompt,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            const SizedBox(height: ToungularSpace.l),
            for (final choice in question.choices) ...<Widget>[
              OutlinedButton(
                onPressed: _busy ? null : () => _choose(question, choice),
                child: Text(choice),
              ),
              const SizedBox(height: ToungularSpace.xs),
            ],
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (_error != null) ...<Widget>[
              const SizedBox(height: ToungularSpace.s),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _choose(
                        question,
                        _answers[question.id] ?? question.choices.first,
                      ),
                child: const Text('Retry saving answers'),
              ),
            ],
          ],
        );
      },
    ),
  );

  Widget _resultContent(PlacementResult result) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(ToungularSpace.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.menu_book_outlined,
            color: ToungularColor.leaf,
            size: 54,
          ),
          const SizedBox(height: ToungularSpace.m),
          Text(
            result.baseline ? 'Baseline saved' : 'Follow-up saved',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: ToungularSpace.s),
          Text(
            '${result.score} of ${result.total}',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: ToungularSpace.s),
          Text(result.label, textAlign: TextAlign.center),
          if (result.change != null) ...<Widget>[
            const SizedBox(height: ToungularSpace.s),
            Text(
              '${result.change! >= 0 ? '+' : ''}${result.change} items from your first check.',
            ),
          ],
          const SizedBox(height: ToungularSpace.l),
          FilledButton(
            onPressed: () => context.pop(),
            child: const Text('See progress'),
          ),
          TextButton(
            onPressed: () => setState(() {
              _index = 0;
              _answers.clear();
              _result = null;
              _error = null;
            }),
            child: const Text('Repeat this check later'),
          ),
        ],
      ),
    ),
  );
}
