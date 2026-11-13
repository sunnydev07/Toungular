import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/toungular_theme.dart';
import '../../core/voice/voice_repository.dart';
import '../../shared/models/learning_models.dart';
import 'vocabulary_repository.dart';

class VocabularyScreen extends ConsumerStatefulWidget {
  const VocabularyScreen({super.key});

  @override
  ConsumerState<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends ConsumerState<VocabularyScreen> {
  final _player = AudioPlayer();
  final _cardStopwatch = Stopwatch();
  late Future<List<VocabularyReview>> _items;
  int _index = 0;
  bool _revealed = false;
  bool _busy = false;
  bool _ttsAvailable = false;
  bool _playing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _items = ref.read(vocabularyRepositoryProvider).loadDueItems();
    _loadVoiceStatus();
    _cardStopwatch.start();
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _loadVoiceStatus() async {
    try {
      final status = await ref.read(voiceRepositoryProvider).status();
      if (mounted) setState(() => _ttsAvailable = status.ttsAvailable);
    } catch (_) {
      // Voice is optional; the recall card still works without it.
    }
  }

  Future<void> _listen(String text) async {
    if (_playing) return;
    setState(() {
      _playing = true;
      _error = null;
    });
    try {
      final path = await ref
          .read(voiceRepositoryProvider)
          .synthesizeToFile(text);
      await _player.setFilePath(path);
      await _player.play();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Audio is unavailable right now. You can still answer from the text.',
        );
      }
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  String? _suggestedGrade() {
    final ms = _cardStopwatch.elapsedMilliseconds;
    if (ms < 3500) return 'easy';
    if (ms <= 8000) return 'good';
    return 'hard';
  }

  Future<void> _grade(String grade) async {
    final items = await _items;
    if (_index >= items.length) return;
    final review = items[_index];
    final elapsedMs = _cardStopwatch.elapsedMilliseconds;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(vocabularyRepositoryProvider)
          .submitReview(
            review.item.id,
            grade,
            mode: review.recallMode,
            responseTimeMs: elapsedMs,
          );
      if (mounted) {
        setState(() {
          _index++;
          _revealed = false;
        });
        _cardStopwatch.reset();
        _cardStopwatch.start();
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'This review could not be saved. Try again.');
      }
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
    _cardStopwatch.reset();
    _cardStopwatch.start();
  }

  Future<void> _addWord() async {
    final draft = await showDialog<_WordDraft>(
      context: context,
      builder: (context) => const _AddWordDialog(),
    );
    if (draft == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(vocabularyRepositoryProvider)
          .addWord(
            word: draft.word,
            partOfSpeech: draft.partOfSpeech,
            definition: draft.definition,
            example: draft.example,
            level: draft.level,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“${draft.word}” added to your reviews.')),
      );
      await _refresh();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'This word could not be added. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _modeHint(VocabularyReview review) => switch (review.recallMode) {
    'cloze' => 'Fill the gap',
    'audio' => 'Listen and recall',
    'sentence' => 'Use it yourself',
    _ => 'Recall the word',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Vocabulary practice'),
      actions: <Widget>[
        IconButton(
          tooltip: 'Add a word',
          onPressed: _busy ? null : _addWord,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: SafeArea(
      child: FutureBuilder<List<VocabularyReview>>(
        future: _items,
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
                      'Reviews could not load',
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
          final items = snapshot.data!;
          if (_index >= items.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(ToungularSpace.l),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.check_circle_outline,
                      size: 52,
                      color: ToungularColor.leaf,
                    ),
                    const SizedBox(height: ToungularSpace.m),
                    Text(
                      'Review complete',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: ToungularSpace.s),
                    const Text(
                      'A quick recall today makes useful words easier to reach later.',
                    ),
                    const SizedBox(height: ToungularSpace.l),
                    FilledButton(
                      onPressed: () => context.pop(),
                      child: const Text('Back to learning path'),
                    ),
                    TextButton(
                      onPressed: _refresh,
                      child: const Text('Check for more reviews'),
                    ),
                    TextButton(
                      onPressed: _addWord,
                      child: const Text('Add a word of your own'),
                    ),
                  ],
                ),
              ),
            );
          }
          final review = items[_index];
          final item = review.item;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              ToungularSpace.l,
              ToungularSpace.m,
              ToungularSpace.l,
              ToungularSpace.xl,
            ),
            children: <Widget>[
              LinearProgressIndicator(value: (_index + 1) / items.length),
              const SizedBox(height: ToungularSpace.s),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Card ${_index + 1} of ${items.length}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  if (review.stability > 0) ...<Widget>[
                    Chip(
                      label: Text('Stability: ${review.stability.toStringAsFixed(1)}d'),
                    ),
                    const SizedBox(width: ToungularSpace.xs),
                  ],
                  Chip(label: Text(_modeHint(review))),
                ],
              ),
              const SizedBox(height: ToungularSpace.l),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(ToungularSpace.xl),
                  child: Column(
                    children: <Widget>[
                      Text(
                        item.tierLabel.toUpperCase(),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: ToungularSpace.l),
                      ..._cardContent(context, review),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: ToungularSpace.l),
              if (!_revealed)
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () {
                          _cardStopwatch.stop();
                          setState(() => _revealed = true);
                        },
                  child: Text(
                    review.recallMode == 'sentence'
                        ? 'Reveal an example'
                        : 'Reveal the word',
                  ),
                )
              else ...<Widget>[
                Text(
                  'How well did you remember it?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: ToungularSpace.s),
                for (final grade in <(String, String)>[
                  ('again', 'Again · show it soon'),
                  ('hard', 'Hard · short interval'),
                  ('good', 'Good · remembered'),
                  ('easy', 'Easy · ready to wait longer'),
                ]) ...<Widget>[
                  OutlinedButton(
                    onPressed: _busy ? null : () => _grade(grade.$1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(grade.$2),
                        if (grade.$1 == _suggestedGrade()) ...<Widget>[
                          const SizedBox(width: ToungularSpace.s),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Suggested',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: ToungularSpace.xs),
                ],
              ],
              if (_error != null) ...<Widget>[
                const SizedBox(height: ToungularSpace.s),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );

  List<Widget> _cardContent(BuildContext context, VocabularyReview review) {
    final item = review.item;
    final textTheme = Theme.of(context).textTheme;
    switch (review.recallMode) {
      case 'cloze':
        return <Widget>[
          Text(
            review.cloze ?? item.example,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: ToungularSpace.m),
          if (!_revealed)
            const Text(
              'Which word completes the sentence?',
              textAlign: TextAlign.center,
            )
          else ...<Widget>[
            Text(
              item.word,
              textAlign: TextAlign.center,
              style: textTheme.displaySmall,
            ),
            const SizedBox(height: ToungularSpace.m),
            Text(
              item.definition,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge,
            ),
          ],
        ];
      case 'audio':
        return <Widget>[
          if (!_revealed) ...<Widget>[
            const Text(
              'Listen, then say the word before you reveal it.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ToungularSpace.m),
            if (_ttsAvailable)
              FilledButton.tonalIcon(
                onPressed: _playing ? null : () => _listen(item.definition),
                icon: const Icon(Icons.volume_up_outlined),
                label: Text(_playing ? 'Loading audio…' : 'Play the meaning'),
              ),
          ] else ...<Widget>[
            Text(
              item.word,
              textAlign: TextAlign.center,
              style: textTheme.displaySmall,
            ),
            const SizedBox(height: ToungularSpace.xs),
            Text(item.partOfSpeech, style: textTheme.bodyMedium),
            const SizedBox(height: ToungularSpace.m),
            Text(
              item.definition,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: ToungularSpace.m),
            Text(
              '“${item.example}”',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
          ],
        ];
      case 'sentence':
        return <Widget>[
          Text(
            item.word,
            textAlign: TextAlign.center,
            style: textTheme.displaySmall,
          ),
          const SizedBox(height: ToungularSpace.xs),
          Text(item.partOfSpeech, style: textTheme.bodyMedium),
          const SizedBox(height: ToungularSpace.m),
          if (!_revealed)
            const Text(
              'Use this word in your own sentence. Say it aloud, then reveal an example.',
              textAlign: TextAlign.center,
            )
          else ...<Widget>[
            Text(
              item.definition,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: ToungularSpace.m),
            Text(
              '“${item.example}”',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: ToungularSpace.s),
            const Text(
              'Grading is your own judgement; Toungular does not validate your sentence.',
              textAlign: TextAlign.center,
            ),
          ],
        ];
      default:
        return <Widget>[
          Text(
            item.definition,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: ToungularSpace.m),
          if (!_revealed)
            const Text(
              'Which word matches this meaning?',
              textAlign: TextAlign.center,
            )
          else ...<Widget>[
            Text(
              item.word,
              textAlign: TextAlign.center,
              style: textTheme.displaySmall,
            ),
            const SizedBox(height: ToungularSpace.xs),
            Text(item.partOfSpeech, style: textTheme.bodyMedium),
            const SizedBox(height: ToungularSpace.m),
            Text(
              '“${item.example}”',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
          ],
        ];
    }
  }
}

class _WordDraft {
  const _WordDraft({
    required this.word,
    required this.partOfSpeech,
    required this.definition,
    required this.example,
    required this.level,
  });

  final String word;
  final String partOfSpeech;
  final String definition;
  final String example;
  final String level;
}

class _AddWordDialog extends StatefulWidget {
  const _AddWordDialog();

  @override
  State<_AddWordDialog> createState() => _AddWordDialogState();
}

class _AddWordDialogState extends State<_AddWordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _word = TextEditingController();
  final _partOfSpeech = TextEditingController(text: 'noun');
  final _definition = TextEditingController();
  final _example = TextEditingController();
  String _level = 'intermediate';

  @override
  void dispose() {
    _word.dispose();
    _partOfSpeech.dispose();
    _definition.dispose();
    _example.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _WordDraft(
        word: _word.text.trim(),
        partOfSpeech: _partOfSpeech.text.trim(),
        definition: _definition.text.trim(),
        example: _example.text.trim(),
        level: _level,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add a word'),
    content: SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: _word,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(labelText: 'Word'),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Enter a word.' : null,
            ),
            const SizedBox(height: ToungularSpace.s),
            TextFormField(
              controller: _partOfSpeech,
              decoration: const InputDecoration(labelText: 'Part of speech'),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Enter a part of speech.'
                  : null,
            ),
            const SizedBox(height: ToungularSpace.s),
            TextFormField(
              controller: _definition,
              decoration: const InputDecoration(labelText: 'Definition'),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Enter a definition.' : null,
            ),
            const SizedBox(height: ToungularSpace.s),
            TextFormField(
              controller: _example,
              decoration: const InputDecoration(labelText: 'Example sentence'),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Enter an example sentence.'
                  : null,
            ),
            const SizedBox(height: ToungularSpace.s),
            DropdownButtonFormField<String>(
              initialValue: _level,
              decoration: const InputDecoration(labelText: 'Level'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
                DropdownMenuItem(
                  value: 'elementary',
                  child: Text('Elementary'),
                ),
                DropdownMenuItem(
                  value: 'intermediate',
                  child: Text('Intermediate'),
                ),
                DropdownMenuItem(
                  value: 'upperIntermediate',
                  child: Text('Upper intermediate'),
                ),
                DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
              ],
              onChanged: (value) => setState(() => _level = value ?? _level),
            ),
          ],
        ),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Add word')),
    ],
  );
}
