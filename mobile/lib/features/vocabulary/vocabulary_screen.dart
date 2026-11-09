import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/toungular_theme.dart';
import '../../shared/models/learning_models.dart';
import 'vocabulary_repository.dart';

class VocabularyScreen extends ConsumerStatefulWidget {
  const VocabularyScreen({super.key});

  @override
  ConsumerState<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends ConsumerState<VocabularyScreen> {
  late Future<List<VocabularyReview>> _items;
  int _index = 0;
  bool _revealed = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _items = ref.read(vocabularyRepositoryProvider).loadDueItems();
  }

  Future<void> _grade(String grade) async {
    final items = await _items;
    if (_index >= items.length) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(vocabularyRepositoryProvider).submitReview(items[_index].item.id, grade);
      if (mounted) setState(() {
        _index++;
        _revealed = false;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'This review could not be saved. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _index = 0;
      _revealed = false;
      _items = ref.read(vocabularyRepositoryProvider).loadDueItems();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Vocabulary practice')),
        body: SafeArea(
          child: FutureBuilder<List<VocabularyReview>>(
            future: _items,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) {
                final error = snapshot.error;
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(ToungularSpace.l),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text('Reviews could not load', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: ToungularSpace.s),
                        Text(error is ApiException ? error.message : 'Reconnect and try again.'),
                        const SizedBox(height: ToungularSpace.m),
                        OutlinedButton(onPressed: _refresh, child: const Text('Try again')),
                      ],
                    ),
                  ),
                );
              }
              final items = snapshot.data!;
              if (_index >= items.length) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(ToungularSpace.l),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.check_circle_outline, size: 52, color: ToungularColor.leaf),
                        const SizedBox(height: ToungularSpace.m),
                        Text('Review complete', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: ToungularSpace.s),
                        const Text('A quick recall today makes useful words easier to reach later.'),
                        const SizedBox(height: ToungularSpace.l),
                        FilledButton(onPressed: () => context.go('/courses'), child: const Text('Back to learning path')),
                        TextButton(onPressed: _refresh, child: const Text('Check for more reviews')),
                      ],
                    ),
                  ),
                );
              }
              final item = items[_index].item;
              return ListView(
                padding: const EdgeInsets.fromLTRB(ToungularSpace.l, ToungularSpace.m, ToungularSpace.l, ToungularSpace.xl),
                children: <Widget>[
                  LinearProgressIndicator(value: (_index + 1) / items.length),
                  const SizedBox(height: ToungularSpace.s),
                  Text('Card ${_index + 1} of ${items.length}', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: ToungularSpace.l),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(ToungularSpace.xl),
                      child: Column(
                        children: <Widget>[
                          Text(item.level.toUpperCase(), style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: ToungularSpace.l),
                          Text(item.word, textAlign: TextAlign.center, style: Theme.of(context).textTheme.displaySmall),
                          const SizedBox(height: ToungularSpace.xs),
                          Text(item.partOfSpeech, style: Theme.of(context).textTheme.bodyMedium),
                          if (_revealed) ...<Widget>[
                            const Divider(height: ToungularSpace.xl),
                            Text(item.definition, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: ToungularSpace.m),
                            Text('“${item.example}”', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                          ] else ...<Widget>[
                            const SizedBox(height: ToungularSpace.m),
                            const Text('Think of the meaning and make a sentence before you reveal it.'),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: ToungularSpace.l),
                  if (!_revealed)
                    FilledButton(onPressed: () => setState(() => _revealed = true), child: const Text('Reveal meaning'))
                  else ...<Widget>[
                    Text('How well did you remember it?', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: ToungularSpace.s),
                    for (final grade in <(String, String)>[
                      ('again', 'Again · show it soon'),
                      ('hard', 'Hard · short interval'),
                      ('good', 'Good · remembered'),
                      ('easy', 'Easy · ready to wait longer'),
                    ]) ...<Widget>[
                      OutlinedButton(
                        onPressed: _busy ? null : () => _grade(grade.$1),
                        child: Text(grade.$2),
                      ),
                      const SizedBox(height: ToungularSpace.xs),
                    ],
                  ],
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: ToungularSpace.s),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                ],
              );
            },
          ),
        ),
      );
}
